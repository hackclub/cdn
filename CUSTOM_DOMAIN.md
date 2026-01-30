# Setting up a custom domain for the files
You need to use a Layer 7 Reverse Proxy that supports changing the Host header, for this example we will use a self-hosted Nginx.

This works with any bucket provider. You will need a server, for performance it is advised to get one physically near to where the S3 bucket is hosted.

If Nginx is not installed, run:
```
sudo apt update && sudo apt install nginx -y
nginx -v
```
If `nginx -v` returns a version, that means you installed it successfully.

Now, create a configuration for the bucket:
```
sudo nano /etc/nginx/sites-available/bucket
```

If you don't want Nginx to do SSL:
> Replace `community-cdn.hackclub-assets.com` with the custom domain and `hc-cdn.hel1.your-objectstorage.com` with the domain of the bucket.
```
server {
    listen 80;
    server_name community-cdn.hackclub-assets.com;

    location / {
        proxy_pass https://hc-cdn.hel1.your-objectstorage.com;

        proxy_set_header Host hc-cdn.hel1.your-objectstorage.com;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
    }
}
```

With SSL certificate:

> Replace `community-cdn.hackclub-assets.com` with the custom domain and `hc-cdn.hel1.your-objectstorage.com` with the domain of the bucket.
> Change the paths for `ssl_certificate` to point to the certificate files.
```
server {
    listen 80;
    server_name community-cdn.hackclub-assets.com;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name community-cdn.hackclub-assets.com;

    ssl_certificate /etc/letsencrypt/live/community-cdn.hackclub-assets.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/community-cdn.hackclub-assets.com/privkey.pem;

    location / {
        proxy_pass https://hc-cdn.hel1.your-objectstorage.com;

        proxy_set_header Host hc-cdn.hel1.your-objectstorage.com;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
    }
}
```

To apply the changes:
```
sudo ln -s /etc/nginx/sites-available/bucket /etc/nginx/sites-enabled/bucket
sudo rm /etc/nginx/sites-available/default && sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

Use an `A` DNS Record to point the custom domain -> the IP of the server
If using Cloudflare proxy, it is advised to whitelist web access to Cloudflare IP ranges on the server's firewall.
If you don't want the bucket to be accessible without using the custom domain, make the bucket private and whitelist the IP of the server.

[Source](https://docs.hetzner.com/storage/object-storage/howto-configurations/domain-nginx)
