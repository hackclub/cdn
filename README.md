<h1 align="center">CDN</h1>
<p align="center"><i>Deep under the waves and storms there lies a <a href="https://app.slack.com/client/T0266FRGM/C016DEDUL87">vault</a>...</i></p>
<p align="center"><img alt="Raft icon" src="http://cloud-pxma0a3yi.vercel.app/underwater.png"></p>
<p align="center">Illustration above by <a href="https://gh.maxwofford.com">@maxwofford</a>.</p>

---

CDN powers the [#cdn](https://app.slack.com/client/T0266FRGM/C016DEDUL87) channel in the [Hack Club Slack](https://hackclub.com/slack).

## Version 2 <img alt="Version 2" src="https://cloud-b46nncb23.vercel.app/0v2.png" align="right" width="300">

Post this JSON...
```js
[
  "website.com/somefile.png",
  "website.com/somefile.gif",
]
```

And it'll return the following:
```js
{
  "0somefile.png": "cdnlink.vercel.app/0somefile.png",
  "1somefile.gif": "cdnlink.vercel.app/1somefile.gif"
}
```

## Version 1 <img alt="Version 1" src="https://cloud-6gklvd3ci.vercel.app/0v1.png" align="right" width="300">

Post this JSON...
```js
[
  "website.com/somefile.png",
  "website.com/somefile.gif",
]
```

And it'll return the following:
```js
[
  "cdnlink.vercel.app/0somefile.png",
  "cdnlink.vercel.app/1somefile.gif"
]
```
