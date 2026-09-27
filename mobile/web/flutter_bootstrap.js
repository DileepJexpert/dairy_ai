{{flutter_js}}
{{flutter_build_config}}

// Older deployments cached main.dart.js before revalidation headers existed.
// Give each build a distinct entrypoint URL without clearing customer storage.
const releaseVersion = {{flutter_service_worker_version}};
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath += '?release=' + encodeURIComponent(releaseVersion);
  }
}

_flutter.loader.load({
  serviceWorkerSettings: {serviceWorkerVersion: releaseVersion}
});
