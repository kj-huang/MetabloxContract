# syntax=docker/dockerfile:1
FROM node:alpine

# install simple http server for serving static content
RUN npm install -g http-server

WORKDIR /code
COPY /views /code/

EXPOSE 8080
CMD [ "http-server", "/code/" ]