import { Hash } from "https://deno.land/x/checksum@1.4.0/mod.ts";

const endpoint = (path: string) => {
  // https://vercel.com/docs/api#api-basics/authentication/accessing-resources-owned-by-a-team
  let url = "https://api.vercel.com/" + path;
  if (Deno.env.get("ZEIT_TEAM")) {
    url += ("?teamId=" + Deno.env.get("ZEIT_TEAM"));
  }
  return url;
};

const uploadFile = async (url: string, authorization: string|null) => {
  const options = {
    method: 'GET', headers: { 'Authorization': "" }
  }
  if (authorization) {
    options.headers = { 'Authorization': authorization }
  }
  const req = await fetch(url, options);
  const data = new Uint8Array(await req.arrayBuffer());
  const sha = new Hash("sha1").digest(data).hex();
  const size = data.byteLength;

  await fetch(endpoint("v2/now/files"), {
    method: "POST",
    headers: {
      "Content-Length": size.toString(),
      "x-now-digest": sha,
      "Authorization": `Bearer ${Deno.env.get("ZEIT_TOKEN")}`,
    },
    body: data.buffer,
  });

  return {
    sha,
    size,
  };
};

export default async (req: Request) => {
  if (req.method != "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed, use POST" }),
      {
        status: 405,
      },
    );
  }

  const decoder = new TextDecoder();
  const buf = await request.arrayBuffer();
  const singleFileURL = decoder.decode(buf);
  if (typeof singleFileURL != "string") {
    return new Response(
      JSON.stringify({ error: "newSingle only accepts a single URL" }),
      {
        status: 422
      },
    );
  }
  const uploadedFileURL = await uploadFile(singleFileURL, req.headers.get("Authorization"));

  return new Response(JSON.stringify(uploadedFileURL))
};
