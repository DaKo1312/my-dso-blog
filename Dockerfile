FROM node:26-alpine AS builder

WORKDIR /app

# The path the site is served under. "/" suits a container that owns the whole
# host name; a reverse proxy that mounts the site below a prefix has to pass that
# prefix here, because the generated asset links are absolute.
ARG BASE_URL="/"

COPY . .

# The same step the deploy workflow performs: example.env holds the values the
# published site is built with. Variables that are already set in the environment
# take precedence over the file, so BASE_URL above wins over the value in it.
RUN cp example.env .env && npm ci && npm run build

FROM nginx:alpine AS runner

COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80
