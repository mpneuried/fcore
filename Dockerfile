FROM node:0.10.39

EXPOSE 8080

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

ONBUILD COPY package.json /usr/src/app/
ONBUILD RUN npm install
ONBUILD RUN grunt build
ONBUILD COPY . /usr/src/app

CMD [ "npm", "start" ]