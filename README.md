# Container deployment of Neko (IN DEVELOPMENT)

Quickly launch a Neko service instance that suits your needs!

<https://gitlab.com/brlin/neko-container>  
[![The GitLab CI pipeline status badge of the project's `main` branch](https://gitlab.com/brlin/neko-container/badges/main/pipeline.svg?ignore_skipped=true "Click here to check out the comprehensive status of the GitLab CI pipelines")](https://gitlab.com/brlin/neko-container/-/pipelines) [![GitHub Actions workflow status badge](https://github.com/brlin-tw/neko-container/actions/workflows/check-potential-problems.yml/badge.svg "GitHub Actions workflow status")](https://github.com/brlin-tw/neko-container/actions/workflows/check-potential-problems.yml) [![pre-commit enabled badge](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white "This project uses pre-commit to check potential problems")](https://pre-commit.com/) [![REUSE Specification compliance badge](https://api.reuse.software/badge/gitlab.com/brlin/neko-container "This project complies to the REUSE specification to decrease software licensing costs")](https://api.reuse.software/info/gitlab.com/brlin/neko-container)

## Limitations

Currently this deployment only supports transmission of credentials over plain-text, do not use any sensitive information in this deployment and always expect such information will be exposed to the public.

## Prerequisites

The following prerequisites must met in order to use this product:

* You must have Docker Compose-compatible environment installed on the server to run this product.
* The server running this product must have Internet access during service deployment.
* The server running the product must be in an environment where WebRTC can reliably work, refer to [WebRTC Configuration | n.eko](https://neko.m1k1o.net/docs/v3/configuration/webrtc) for more information.

## How to use

Refer to the following instructions to use this product:

1. Download the release archive from [the Releases page](https://gitlab.com/brlin/neko-container/-/releases).
1. Extract the release archive using your preferred archive manipulation software.
1. Edit [the compose configuration file](compose.yml) to suit your needs.
1. In a text terminal, switch the working directory to the extracted folder.
1. Run the following command to create the container and start the service:

    ```bash
    docker compose up -d
    ```

1. Access the Neko service by navigating to `http://<your-server-ip>:8080` in your web browser.

## Notes

The following are the notes for using this product:

### How to add favicons for bookmarks?

Firefox doesn't allow URLs in the value of the Bookmarks.Favicon policy key (contrary to the documentation), you must embed the data of the favicon into the policy using the data URI scheme.

You may do so in a Wayland Linux session by runnint the following command:

```bash
curl https://example.com/favicon.ico \
    | base64 \
    | tr --delete '\n' \
    | wl-copy
```

This copies the base64-encoded favicon to your clipboard, which can be pasted into the `Favicon` field using the following syntax:

```text
data:image/vnd.microsoft.icon;base64,PASTE-FAVICON-DATA-HERE
```

## References

The following materials are referenced during the development of this product:

* [data: URLs | MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/URI/Reference/Schemes/data#Common_problems)  
  Explains the syntax of the Data URLs.

## Licensing

Unless otherwise noted([comment headers](https://reuse.software/spec-3.3/#comment-headers)/[REUSE.toml](https://reuse.software/spec-3.3/#reusetoml)), this product is licensed under [the 2.0 version of the Apache License](https://www.apache.org/licenses/LICENSE-2.0), or any of its more recent versions of your preference.

This work complies to [the REUSE Specification](https://reuse.software/spec/), refer to the [REUSE - Make licensing easy for everyone](https://reuse.software/) website for info regarding the licensing of this product.
