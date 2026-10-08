# One image serves both the public website (/) and the API (/api).

# 1. Build the React website (backend/site) to static files.
FROM node:22-alpine AS site
WORKDIR /site
COPY site/package.json site/package-lock.json ./
RUN npm ci
COPY site/ ./
RUN npm run build

# 2. Build the Go server. Pinned to the module's toolchain floor (go.mod: go 1.26.0).
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /server ./cmd/server

FROM alpine:3.20
RUN apk add --no-cache ca-certificates wget
WORKDIR /app
COPY --from=build /server /app/server
COPY --from=site /site/dist /app/site
# The server serves this folder for every path outside /api.
ENV SITE_DIR=/app/site
EXPOSE 8080
ENTRYPOINT ["/app/server"]
