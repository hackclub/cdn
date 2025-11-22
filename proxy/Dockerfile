FROM nginx:alpine

# Remove default config
RUN rm /etc/nginx/conf.d/default.conf

# Copy local config
COPY bucket.conf /etc/nginx/conf.d/bucket.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
