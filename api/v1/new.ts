import { urlParse } from "https://deno.land/x/url_parse/mod.ts";

const endpoint = (path: string) => {
  // https://vercel.com/docs/api#api-basics/authentication/accessing-resources-owned-by-a-team
  let url = "https://api.vercel.com/" + path;
  if (Deno.env.get("ZEIT_TEAM")) {
    url += ("?teamId=" + Deno.env.get("ZEIT_TEAM"));
  }
  return url;
};

const deploy = async (
  files: { sha: string; file: string; path: string; size: number }[],
) => {
  const req = await fetch(endpoint("v12/now/deployments"), {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("ZEIT_TOKEN")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      name: "cloud",
      files: files.map((f) => ({
        sha: f.sha,
        file: f.file,
        size: f.size,
      })),
      projectSettings: {
        framework: null,
      },
    }),
  });
  const json = await req.text();
  console.log(json)
  const baseURL = JSON.parse(json).url;
  const fileURLs = files.map((f) => "https://" + baseURL + "/" + f.path);

  return { status: req.status, fileURLs };
};

export default async (req: Request) => {
  if (req.method == "OPTIONS") {
    return new Response(
      JSON.stringify(
        { status: "YIPPE YAY. YOU HAVE CLEARANCE TO PROCEED." },
      ),
      {
        status: 204
      },
    );
  }
  if (req.method == "GET") {
    return new Response(
      JSON.stringify(
        { error: "*GET outta here!* (Method not allowed, use POST)" },
      ),
      {
        status: 405
      },
    );
  }
  if (req.method == "PUT") {
    return new Response(
      JSON.stringify(
        { error: "*PUT that request away!* (Method not allowed, use POST)" },
      ),
      {
        status: 405,
      },
    );
  }
  if (req.method != "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed, use POST" }),
      {
        status: 405,
      },
    );
  }

  const decoder = new TextDecoder();
  const buf = await req.arrayBuffer();
  console.log(decoder.decode(buf))
  console.log(buf)
  const fileURLs = decoder.decode(buf);
  if (!Array.isArray(fileURLs) || fileURLs.length < 1) {
    return new Response(
      JSON.stringify({ error: "Empty file array" }),
      { status: 422 }
    );
  }

  const authorization = req.headers.get("Authorization");

  const uploadedURLs = await Promise.all(fileURLs.map(async (url, index) => {
    const { pathname } = urlParse(url);
    const filename = index + pathname.substr(pathname.lastIndexOf("/") + 1);

    const headers = {
      "Content-Type": "application/json",
      "Authorization": ""
    }
    if (authorization) {
      headers['Authorization'] = authorization;
    }
    const res = await (await fetch("https://cdn.hackclub.com/api/newSingle", {
      method: "POST",
      headers,
      body: url,
    })).json();

    res.file = "public/" + filename;
    res.path = filename;

    return res;
  }));

  const result = await deploy(uploadedURLs);
  
  return new Response(
    JSON.stringify(result.fileURLs),
    { status: result.status }
  );
};
