import { ServerRequest } from 'https://deno.land/std@0.75.0/http/server.ts'
import { Hash } from "https://deno.land/x/checksum@1.4.0/mod.ts"
import { urlParse } from 'https://deno.land/x/url_parse/mod.ts';

const uploadFile = async (url: string) => {
    const req = await fetch(url)
    const data = new Uint8Array(await req.arrayBuffer())
    const sha = new Hash('sha1').digest(data).hex()
    const size = data.byteLength
    const { pathname } = urlParse(url)
    const filename = pathname.substr(pathname.lastIndexOf('/') + 1)
    
    await fetch(endpoint('v2/now/files'), {
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

export default async (req: ServerRequest) => {
    if (req.method != 'POST') {
        return req.respond({ status: 405, body: JSON.stringify({ error: 'Method not allowed, use POST' }) })
    }

    const decoder = new TextDecoder()
    const buf = await Deno.readAll(req.body)
    const singleFileURL = JSON.parse(decoder.decode(buf))
    if (typeof singleFileURL != 'string') {
        return req.respond({ status: 422, body: JSON.stringify({ error: 'newSingle only accepts a single URL' }) })
    }
    const uploadedFileURL = await uploadFile(singleFileURL)

    req.respond({
        body: JSON.stringify(uploadedFileURL)
    })
}
