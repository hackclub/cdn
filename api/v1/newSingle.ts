import { ServerRequest } from "https://deno.land/std@0.75.0/http/server.ts";
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

export default async (req: ServerRequest) => {
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
  const singleFileURL = decoder.decode(buf);
  if (typeof singleFileURL != "string") {
    return req.respond(
      {
        status: 422,
        body: JSON.stringify({ error: "newSingle only accepts a single URL" }),
      },
    );
  }
  const uploadedFileURL = await uploadFile(singleFileURL, req.headers.get("Authorization"));

  req.respond({
    body: JSON.stringify(uploadedFileURL),
  });
};
