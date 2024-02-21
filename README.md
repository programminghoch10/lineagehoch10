# lineagehoch10
LineageOS by programminghoch10. Less quality, more bugs. What else do you need?

[![GitHub Global Download Counter](https://img.shields.io/github/downloads/programminghoch10/lineagehoch10/total?logo=github)](https://github.com/programminghoch10/lineagehoch10/releases)

[![GitHub Repo stars](https://img.shields.io/github/stars/programminghoch10/lineagehoch10?style=social)](https://github.com/programminghoch10/lineagehoch10/stargazers) \
[![GitHub followers](https://img.shields.io/github/followers/programminghoch10?style=social)](https://github.com/programminghoch10)

## Supported Devices

* `beyond0lte`
* `beyond1lte`
* `beyond2lte`
* `gta4xlwifi`
* `gts4lv`

## Developer Usage

For simplicity we let `repo` check out this repository automatically as part of the android source tree:

`.repo/local_manifests/lineagehoch10.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project path="lineagehoch10" remote="github" name="programminghoch10/lineagehoch10" revision="main" />
  <project path="lineagehoch10/deploy" remote="github" name="programminghoch10/lineagehoch10" revision="deploy" />
</manifest>
```

Set the prop `lineage.updater.uri` or the Updater overlay to 
```
https://raw.githubusercontent.com/programminghoch10/lineagehoch10/deploy/{device}.json
```

Then upload a release zip by running
```sh
lineagehoch10/generateotaupdate.sh out/target/product/<device>/lineage-20.0-<...>.zip
```
from the android build root.
