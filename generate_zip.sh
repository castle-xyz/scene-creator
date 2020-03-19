#!/bin/bash

cp -R . ../scene-creator-tmp
pushd ../scene-creator-tmp

rm .DS_Store
rm assets/.DS_Store
rm behaviors/.DS_Store
rm lib/.DS_Store
rm multi/.DS_Store
rm tools/.DS_Store
rm .castleid
rm -rf .git
rm .gitmodules
rm .npmignore
rm generate_zip.sh
rm cover.png
rm project.castle
rm -rf multi/Example*
rm multi/README.md
rm scene_creator.zip

zip -r ../scene_creator.zip .

popd

rm -rf ../scene-creator-tmp
mv ../scene_creator.zip scene_creator.love