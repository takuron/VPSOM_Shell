准备工作

    域名和 DNS 解析:

        您需要一个自己的域名，例如 your-domain.com。

        创建两个 A 记录，将 traefik.your-domain.com 和 webui.your-domain.com 指向您服务器的公网 IP 地址。

    创建目录结构:
    在您的服务器上，创建一个项目目录，并在其中创建 Traefik 的配置子目录。

    mkdir -p my-docker-stack/traefik/conf
    cd my-docker-stack

    创建 Docker 网络:
    Traefik 需要一个专用的网络来与其它容器通信。

    docker network create proxy

配置文件设置

    创建 Traefik Compose 文件:
    将上面第一个代码块的内容保存为 docker-compose.traefik.yml。

    创建 Traefik 静态配置文件:
    将第二个代码块的内容保存到 traefik/traefik.yml。

        重要: 修改 certificatesResolvers.myresolver.acme.email 为您自己的邮箱。

        重要: 根据您的 DNS 提供商，修改 dnsChallenge.provider。如果您使用 Cloudflare，您需要在 docker-compose.traefik.yml 的 traefik 服务下添加环境变量来提供 API 密钥。例如：

        # 在 docker-compose.traefik.yml 的 traefik 服务中添加
        environment:
          - CF_API_EMAIL=your-cloudflare-email@example.com
          - CF_API_KEY=your_cloudflare_api_key

    创建 Traefik 动态配置文件 (用于认证):
    将第三个代码块的内容保存到 traefik/conf/middlewares.yml。

        生成密码: 您需要为仪表盘创建一个用户名和密码。使用 htpasswd 工具生成：

        # 如果没有安装，请先安装 apache2-utils
        # sudo apt-get update && sudo apt-get install apache2-utils
        htpasswd -nb your_user your_secure_password

        将命令输出的 your_user:$apr1$.... 完整地复制并替换掉 middlewares.yml 中的占位符。

    创建证书文件:
    Traefik 需要一个地方来存储 ACME (Let's Encrypt) 证书。

    touch traefik/acme.json
    chmod 600 traefik/acme.json # 设置正确的文件权限，非常重要！

    创建应用 Compose 文件:
    将第四个代码块的内容保存为 docker-compose.app.yml。

        重要: 将 traefik.http.routers.open-webui.rule 中的 webui.your-domain.com 替换为您自己的域名。

启动服务

    启动 Traefik 和 Watchtower:
    在 my-docker-stack 目录下，运行：

    docker compose -f docker-compose.traefik.yml up -d

    启动 Open-WebUI 应用:
    接着，启动您的应用程序：

    docker compose -f docker-compose.app.yml up -d

验证

    等待片刻，让 Traefik 获取 SSL 证书。

    访问 https://traefik.your-domain.com，您应该会看到一个需要输入用户名和密码的登录框。使用您刚才生成的凭据登录，即可看到 Traefik 仪表盘。

    访问 https://webui.your-domain.com，您应该能看到 open-webui 的界面。

    所有流量都已自动通过 HTTPS 加密。

现在，您的服务已经通过 Traefik 成功暴露，并且配置是解耦的、可扩展的。将来添加新服务时，只需在新的 Compose 文件中添加类似的 Traefik 标签即可。
