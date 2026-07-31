FROM nginx:1.31.3

COPY nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /etc/nginx/html \
    && mkdir -p /var/cache/nginx \
    && chown -R nginx:nginx /var/cache/nginx

USER nginx
