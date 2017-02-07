import PackageDescription
let package = Package(
  name: "ghapp",
  dependencies: [
    .Package(url: "https://github.com/oarrabi/Guaka.git", majorVersion: 0)
  ]
)
