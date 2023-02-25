import { Hash } from "https://deno.land/x/checksum@1.4.0/hash.ts";
import { endpoint, ensurePost, parseBody } from "./utils.ts";

// Other functions can import this function to call this serverless endpoint
export const uploadEndpoint = async (url: string, authorization: string | null) => {
  const options = { method: 'POST', body: url, headers: {} }
  if (authorization) {
    options.headers = { 'Authorization': authorization }
  }
  console.log({ options})
  const response = await fetch("https://cdn.hackclub.com/api/v2/upload", options);
  const result = await response.json();
  console.log({result})

  return result;
};

const upload = async (url: string, authorization: string | null) => {
  const options = { headers: {} }
  if (authorization) {
    options.headers = { 'Authorization': authorization }
  }
  const req = await fetch(url, options);
  const reqArrayBuffer = await req.arrayBuffer();
  const data = new Uint8Array(reqArrayBuffer);
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
    url,
    sha,
    size,
  };
};

export default async (req: Request) => {
  if (!ensurePost(req)) return null;

  const body =await request.arrayBuffer();
  const uploadedFileUrl = await upload(body, req.headers.get("Authorization"));

  return new Response(JSON.stringify(uploadedFileUrl));
};
