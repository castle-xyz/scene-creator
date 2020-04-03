#!/bin/bash

cd ..

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
rm -rf scripts
rm cover.png
rm project.castle
rm -rf multi/Example*
rm multi/README.md
rm scene_creator.love

zip -r ../scene_creator.zip .

popd

rm -rf ../scene-creator-tmp
mv ../scene_creator.zip scene_creator.love