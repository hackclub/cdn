import { ServerRequest } from 'https://deno.land/std@0.61.0/http/server.ts'
import { Hash } from "https://deno.land/x/checksum@1.4.0/mod.ts"
import { urlParse } from 'https://deno.land/x/url_parse/mod.ts';

// Vercel protects against env tokens starting with `VERCEL_`, so we're calling
// it the ZEIT_TOKEN

const uploadFile = async (url: string, index: number) => {
  const req = await fetch(url)
  const data = new Uint8Array(await req.arrayBuffer())
  const sha = new Hash('sha1').digest(data).hex()
  const size = data.byteLength
  const { pathname } = urlParse(url)
  const filename = index + pathname.substr(pathname.lastIndexOf('/') + 1)
  
  const uploadedFile = await fetch('https://api.vercel.com/v2/now/files', {
    method: 'POST',
    headers: {
      'Content-Length': size.toString(),
      'x-now-digest': sha,
      'Authorization': `Bearer ${Deno.env.get('ZEIT_TOKEN')}`
    },
    body: data.buffer,
  })

  return {
    sha,
    size,
    file: 'public/' + filename,
    path: filename
  }
}

const deploy = async (files: {sha: string, file: string, path: string, size: number}[]) => {
  const req = await fetch('https://api.vercel.com/v12/now/deployments', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('ZEIT_TOKEN')}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      name: 'cloud',
      files: files.map(f => ({
        sha: f.sha,
        file: f.file,
        size: f.size
      })),
      projectSettings: {
        framework: null
      }
    })
  })
  const json = await req.json()
  const baseURL = json.url
  const fileURLs = files.map(f => 'https://' + baseURL + '/' + f.path)

  return { status: req.status, fileURLs }
}

export default async (req: ServerRequest) => {
  // req.respond({ body: `Hello, from Deno!` })
  if (req.method == 'OPTIONS') {
    return req.respond({status: 204, body: JSON.stringify({ status: "YIPPE YAY. YOU HAVE CLEARANCE TO PROCEED." })})
  }
  if (req.method == 'GET') {
    return req.respond({status: 405, body: JSON.stringify({ error: '*GET outta here!* (Method not allowed, use POST)' })})
  }
  if (req.method == 'PUT') {
    return req.respond({status: 405, body: JSON.stringify({ error: '*PUT that request away!* (Method not allowed, use POST)' })})
  }
  if (req.method != 'POST') {
    return req.respond({status: 405, body: JSON.stringify({ error: 'Method not allowed, use POST' })})
  }

  const decoder = new TextDecoder()
  const buf = await Deno.readAll(req.body)
  const fileURLs = JSON.parse(decoder.decode(buf))
  if (!Array.isArray(fileURLs) || fileURLs.length < 1) {
    return req.respond({status: 422, body: JSON.stringify({ error: 'Empty file array' })})
  }
  const uploadedFiles = await Promise.all(fileURLs.map(uploadFile))
  const result = await deploy(uploadedFiles)

  req.respond({
    status: result.status,
    body: JSON.stringify(result.fileURLs)
  })
}
