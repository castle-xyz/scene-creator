#!/usr/bin/env node

const SCENE_CREATOR_API_VERSION = 33;

var fs = require("fs");
var request = require("request");

var token = process.env["TOKEN"];

if (!token) {
  var tokenFilename = "../../ghost-secret/ci-secret-file.txt";
  var token = fs.readFileSync(tokenFilename, "utf8");
}

let version = SCENE_CREATOR_API_VERSION;
if (process.env["API_VERSION"]) {
  version = process.env["API_VERSION"];
}

request.post(
  {
    url: "https://api.castle.xyz/api/scene-creator/upload",
    headers: {
      "X-Auth-Token": token,
      "scene-creator-api-version": version,
    },
    formData: {
      file: fs.createReadStream("../scene_creator.love"),
    },
  },
  function (err, resp, body) {
    if (err || resp.statusCode != 200) {
      console.log("Error! " + resp.body);
      process.exit(1);
    } else {
      console.log("Success!");
      process.exit(0);
    }
  }
);
