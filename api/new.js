// https://api.vercel.com/v2/now/files

// https://api.vercel/v12/now/files

// Vercel protects against env tokens starting with `VERCEL_`, so we're calling
// it the ZEIT_TOKEN
const zeitToken = process.env.ZEIT_TOKEN

export default (req, res) => {
  if (req.method == 'OPTIONS') {
    return res.status(204).json({ status: "YIPPE YAY. YOU HAVE CLEARANCE TO PROCEED." })
  }
  if (req.method == 'GET') {
    return res.status(405).json({ error: '*GET outta here!* (Method not allowed, use POST)' })
  }
  if (req.method == 'PUT') {
    return res.status(405).json({ error: '*PUT that request away!* (Method not allowed, use POST)' })
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed, use POST' })
  }

  res.send(req.body)

  // res.json({ ping: 'pong' })
}