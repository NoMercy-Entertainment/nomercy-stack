FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 go build -o /txt-updater .

FROM gcr.io/distroless/static-debian12
COPY --from=build /txt-updater /txt-updater
ENTRYPOINT ["/txt-updater"]
