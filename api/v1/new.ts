import { ServerRequest } from "https://deno.land/std@0.75.0/http/server.ts";
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
  const json = await req.json();
  const baseURL = json.url;
  const fileURLs = files.map((f) => "https://" + baseURL + "/" + f.path);

  return { status: req.status, fileURLs };
};

export default async (req: ServerRequest) => {
  if (req.method == "OPTIONS") {
    return req.respond(
      {
        status: 204,
        body: JSON.stringify(
          { status: "YIPPE YAY. YOU HAVE CLEARANCE TO PROCEED." },
        ),
      },
    );
  }
  if (req.method == "GET") {
    return req.respond(
      {
        status: 405,
        body: JSON.stringify(
          { error: "*GET outta here!* (Method not allowed, use POST)" },
        ),
      },
    );
  }
  if (req.method == "PUT") {
    return req.respond(
      {
        status: 405,
        body: JSON.stringify(
          { error: "*PUT that request away!* (Method not allowed, use POST)" },
        ),
      },
    );
  }
  if (req.method != "POST") {
    return req.respond(
      {
        status: 405,
        body: JSON.stringify({ error: "Method not allowed, use POST" }),
      },
    );
  }

  const decoder = new TextDecoder();
  const buf = await Deno.readAll(req.body);
  const fileURLs = JSON.parse(decoder.decode(buf));
  if (!Array.isArray(fileURLs) || fileURLs.length < 1) {
    return req.respond(
      { status: 422, body: JSON.stringify({ error: "Empty file array" }) },
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
    const res = await (await fetch("http://localhost:3000/api/newSingle", {
      method: "POST",
      headers,
      body: url,
    })).json();

    res.file = "public/" + filename;
    res.path = filename;

    return res;
  }));

  const result = await deploy(uploadedURLs);

  req.respond({
    status: result.status,
    body: JSON.stringify(result.fileURLs),
  });
};
