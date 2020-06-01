#!/usr/bin/env node

const SCENE_CREATOR_API_VERSION = 4;

var fs = require("fs");
var request = require("request");

var token = process.env["TOKEN"];

if (!token) {
  var tokenFilename = "../../ghost-secret/ci-secret-file.txt";
  var token = fs.readFileSync(tokenFilename, "utf8");
}

request.post(
  {
    url: "https://api.castle.games/api/scene-creator/upload",
    headers: {
      "X-Auth-Token": token,
      "scene-creator-api-version": SCENE_CREATOR_API_VERSION,
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
