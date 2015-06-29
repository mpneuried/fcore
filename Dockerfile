FROM node:0.10.39

EXPOSE 8080

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY package.json /usr/src/app/
RUN npm install
COPY . /usr/src/app
RUN npm install -g grunt-cli
RUN grunt build

CMD [ "npm", "start" ]