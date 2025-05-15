const express = require("express");
const app = express();
const axios = require("axios");
const os = require('os');
const fs = require("fs");
const path = require("path");
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);

// --- 配置参数 ---
// 这些值将由setup-argo.sh脚本自动修改，无需手动编辑
const UPLOAD_URL = '';      // 节点或订阅自动上传地址,没有则不填
const PROJECT_URL = '';    // 填写项目分配的url
const AUTO_ACCESS = true; // false关闭自动保活，true开启
const FILE_PATH = './tmp';   // 运行目录,sub节点文件保存目录
const SUB_PATH = 'sub';       // 订阅路径
const PORT = 3001;        // http服务订阅端口
console.log("使用端口:", PORT);
const UUID = ''; // 使用哪吒v1,在不同的平台运行需修改UUID
const NEZHA_SERVER = '';        // 哪吒v1填写形式: nz.abc.com:8008  哪吒v0填写形式：nz.abc.com
const NEZHA_PORT = '';            // 使用哪吒v1请留空，哪吒v0需填写
const NEZHA_KEY = '';              // 哪吒v1的NZ_CLIENT_SECRET或哪吒v0的agent密钥
const ARGO_DOMAIN = '';          // 固定隧道域名,留空即启用临时隧道
const ARGO_AUTH = '';              // 固定隧道密钥json或token
const ARGO_PORT = 8001;            // 固定隧道端口
const CFIP = 'www.visa.com.tw';         // 节点优选域名或优选ip
const CFPORT = 443;                   // 节点优选域名或优选ip对应的端口
const NAME = 'argo-ws';                     // 节点名称

// --- 文件路径 ---
let npmPath = path.join(FILE_PATH, 'npm');
let phpPath = path.join(FILE_PATH, 'php');
let webPath = path.join(FILE_PATH, 'web');
let botPath = path.join(FILE_PATH, 'bot');
let subPath = path.join(FILE_PATH, 'sub.txt');
let listPath = path.join(FILE_PATH, 'list.txt');
let bootLogPath = path.join(FILE_PATH, 'boot.log');
let configPath = path.join(FILE_PATH, 'config.json');
let tunnelJsonPath = path.join(FILE_PATH, 'tunnel.json');
let tunnelYmlPath = path.join(FILE_PATH, 'tunnel.yml');
let nezhaConfigYamlPath = path.join(FILE_PATH, 'config.yaml');

//创建运行文件夹
if (!fs.existsSync(FILE_PATH)) {
  fs.mkdirSync(FILE_PATH);
  console.log(`${FILE_PATH} is created`);
} else {
  console.log(`${FILE_PATH} already exists`);
}

// 如果订阅器上存在历史运行节点则先删除
async function deleteNodes() {
  try {
    if (!UPLOAD_URL) return;
    if (!fs.existsSync(subPath)) return;

    let fileContent;
    try {
      fileContent = fs.readFileSync(subPath, 'utf-8');
    } catch (err) {
      console.error(`Error reading sub.txt: ${err.message}`);
      return null;
    }

    const decoded = Buffer.from(fileContent, 'base64').toString('utf-8');
    const nodes = decoded.split('\n').filter(line =>
      /(vless|vmess|trojan|hysteria2|tuic):\/\//.test(line)
    );

    if (nodes.length === 0) return;

    console.log(`Attempting to delete ${nodes.length} nodes from subscription service...`);
    return axios.post(`${UPLOAD_URL}/api/delete-nodes`,
      JSON.stringify({ nodes }),
      { headers: { 'Content-Type': 'application/json' } }
    ).then(response => {
      console.log('Nodes deleted successfully');
      return response;
    }).catch((error) => {
      console.error(`Failed to delete nodes: ${error.message}`);
      return null;
    });
  } catch (err) {
    console.error(`Error in deleteNodes: ${err.message}`);
    return null;
  }
}

//清理历史文件
function cleanupOldFiles() {
  console.log('Cleaning up old files...');
  const pathsToDelete = ['web', 'bot', 'npm', 'php', 'sub.txt', 'boot.log', 'tunnel.json', 'tunnel.yml', 'config.yaml'];
  pathsToDelete.forEach(file => {
    const filePath = path.join(FILE_PATH, file);
    // 使用rm -rf处理文件和目录，忽略不存在的文件错误
    exec(`rm -rf ${filePath}`).catch(() => { });
  });
  console.log('Old files cleanup completed');
}

// 根路由
app.get("/", function (req, res) {
  res.send("Proxy service with Nezha Agent and Cloudflare Tunnel is running!");
});

// 生成xr-ay配置文件
function generateXrayConfig() {
  console.log('Generating xr-ay configuration...');
  const config = {
    log: { access: '/dev/null', error: '/dev/null', loglevel: 'none' },
    inbounds: [
      { port: ARGO_PORT, protocol: 'vless', settings: { clients: [{ id: UUID, flow: 'xtls-rprx-vision' }], decryption: 'none', fallbacks: [{ dest: 3001 }, { path: "/vless-argo", dest: 3002 }, { path: "/vmess-argo", dest: 3003 }, { path: "/trojan-argo", dest: 3004 }] }, streamSettings: { network: 'tcp' } },
      { port: 3001, listen: "127.0.0.1", protocol: "vless", settings: { clients: [{ id: UUID }], decryption: "none" }, streamSettings: { network: "tcp", security: "none" } },
      { port: 3002, listen: "127.0.0.1", protocol: "vless", settings: { clients: [{ id: UUID, level: 0 }], decryption: "none" }, streamSettings: { network: "ws", security: "none", wsSettings: { path: "/vless-argo" } }, sniffing: { enabled: true, destOverride: ["http", "tls", "quic"], metadataOnly: false } },
      { port: 3003, listen: "127.0.0.1", protocol: "vmess", settings: { clients: [{ id: UUID, alterId: 0 }] }, streamSettings: { network: "ws", wsSettings: { path: "/vmess-argo" } }, sniffing: { enabled: true, destOverride: ["http", "tls", "quic"], metadataOnly: false } },
      { port: 3004, listen: "127.0.0.1", protocol: "trojan", settings: { clients: [{ password: UUID }] }, streamSettings: { network: "ws", security: "none", wsSettings: { path: "/trojan-argo" } }, sniffing: { enabled: true, destOverride: ["http", "tls", "quic"], metadataOnly: false } },
    ],
    dns: { servers: ["https+local://8.8.8.8/dns-query"] },
    outbounds: [{ protocol: "freedom", tag: "direct" }, { protocol: "blackhole", tag: "block" }]
  };
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  console.log('xr-ay configuration generated successfully');
}

// 判断系统架构
function getSystemArchitecture() {
  const arch = os.arch();
  if (arch === 'arm' || arch === 'arm64' || arch === 'aarch64') {
    return 'arm';
  } else {
    return 'amd';
  }
}

// 下载对应系统架构的依赖文件
function downloadFile(fileName, fileUrl, callback) {
  const filePath = path.join(FILE_PATH, fileName);

  // 检查文件是否已存在，如果存在则跳过下载
  if (fs.existsSync(filePath)) {
    console.log(`${fileName} already exists, skipping download.`);
    setTimeout(() => callback(null, fileName), 0);
    return;
  }

  console.log(`Attempting to download ${fileName} from ${fileUrl}`);
  const writer = fs.createWriteStream(filePath);

  axios({
    method: 'get',
    url: fileUrl,
    responseType: 'stream',
    timeout: 30000 // 30秒超时
  })
    .then(response => {
      response.data.pipe(writer);

      writer.on('finish', () => {
        writer.close();
        console.log(`Download ${fileName} successfully`);
        callback(null, fileName);
      });

      writer.on('error', err => {
        fs.unlink(filePath, () => { }); // 清理不完整的文件
        const errorMessage = `Download ${fileName} failed (writer error): ${err.message}`;
        console.error(errorMessage);
        callback(errorMessage);
      });
    })
    .catch(err => {
      if (fs.existsSync(filePath)) {
        fs.unlink(filePath, () => { }); // 清理可能不完整的文件
      }
      const errorMessage = `Download ${fileName} failed (axios error): ${err.message}`;
      console.error(errorMessage);
      callback(errorMessage);
    });
}

// 下载并运行依赖文件
async function downloadFilesAndRun() {
  const architecture = getSystemArchitecture();
  console.log(`Detected system architecture: ${architecture}`);
  const filesToDownload = getFilesForArchitecture(architecture);

  if (filesToDownload.length === 0) {
    console.log(`Can't find files for the current architecture`);
    return;
  }

  console.log(`Files to download: ${filesToDownload.map(f => f.fileName).join(', ')}`);

  const downloadPromises = filesToDownload.map(fileInfo => {
    return new Promise((resolve, reject) => {
      downloadFile(fileInfo.fileName, fileInfo.fileUrl, (err, fileName) => {
        if (err) {
          console.error(`Failed to download ${fileInfo.fileName}: ${err}`);
          resolve(null); // 允许其他下载继续
        } else {
          resolve(fileName);
        }
      });
    });
  });

  try {
    const downloadedFiles = await Promise.all(downloadPromises);
    const successfullyDownloaded = downloadedFiles.filter(name => name !== null);

    // 检查必要文件是否下载成功
    if (!successfullyDownloaded.includes('web')) {
      console.error("Essential file 'web' (proxy service) failed to download.");
    }
    if (!successfullyDownloaded.includes('bot')) {
      console.error("Essential file 'bot' (cloudflared) failed to download.");
    }
    if (NEZHA_SERVER && NEZHA_KEY) {
      const nezhaAgentFile = NEZHA_PORT ? 'npm' : 'php';
      if (!successfullyDownloaded.includes(nezhaAgentFile)) {
        console.error(`Essential file '${nezhaAgentFile}' (Nezha agent) failed to download.`);
      }
    }

    console.log('File download process completed.');
  } catch (err) {
    console.error('Error downloading files:', err);
    return;
  }

  // 授权和运行
  function authorizeFiles(filePaths) {
    const newPermissions = 0o775; // rwxrwxr-x
    filePaths.forEach(relativeFilePath => {
      const absoluteFilePath = path.join(FILE_PATH, relativeFilePath);
      if (fs.existsSync(absoluteFilePath)) {
        try {
          fs.chmodSync(absoluteFilePath, newPermissions);
          console.log(`Empowerment success for ${absoluteFilePath}: ${newPermissions.toString(8)}`);
        } catch (err) {
          console.error(`Empowerment failed for ${absoluteFilePath}: ${err}`);
        }
      } else {
        console.warn(`Cannot authorize ${absoluteFilePath}: File does not exist.`);
      }
    });
  }

  // 确定需要授权的文件
  const filesToAuthorize = ['web', 'bot'];
  if (NEZHA_SERVER && NEZHA_KEY) {
    filesToAuthorize.push(NEZHA_PORT ? 'npm' : 'php');
  }
  authorizeFiles(filesToAuthorize);

  //运行ne-zha
  if (NEZHA_SERVER && NEZHA_KEY && fs.existsSync(path.join(FILE_PATH, NEZHA_PORT ? 'npm' : 'php'))) {
    if (!NEZHA_PORT) { // 使用哪吒v1 (php文件)
      // 检测哪吒是否开启TLS
      const port = NEZHA_SERVER.includes(':') ? NEZHA_SERVER.split(':').pop() : '';
      const tlsPorts = new Set(['443', '8443', '2096', '2087', '2083', '2053']);
      const nezhatls = tlsPorts.has(port) ? 'true' : 'false';

      // 生成 config.yaml
      const configYaml = `
client_secret: ${NEZHA_KEY}
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 1
server: ${NEZHA_SERVER}
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: ${nezhatls}
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: ${UUID}`;

      try {
        fs.writeFileSync(nezhaConfigYamlPath, configYaml);
        console.log('Generated Nezha v1 config.yaml');

        // 运行 php (哪吒v1 agent)
        const command = `nohup ${phpPath} -c "${nezhaConfigYamlPath}" >/dev/null 2>&1 &`;
        await exec(command);
        console.log('Nezha v1 agent (php) is starting...');
        await new Promise((resolve) => setTimeout(resolve, 1000));
      } catch (error) {
        console.error(`Nezha v1 agent (php) startup error: ${error}`);
      }
    } else { // 使用哪吒v0 (npm文件)
      let NEZHA_TLS = '';
      const tlsPorts = ['443', '8443', '2096', '2087', '2083', '2053'];
      if (tlsPorts.includes(NEZHA_PORT)) {
        NEZHA_TLS = '--tls';
      }
      const command = `nohup ${npmPath} -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &`;
      try {
        await exec(command);
        console.log('Nezha v0 agent (npm) is starting...');
        await new Promise((resolve) => setTimeout(resolve, 1000));
      } catch (error) {
        console.error(`Nezha v0 agent (npm) startup error: ${error}`);
      }
    }
  } else if (NEZHA_SERVER && NEZHA_KEY) {
    console.warn('Nezha variables are set, but the agent executable is missing. Skipping Nezha agent start.');
  } else {
    console.log('Nezha variables not fully set, skipping Nezha agent start.');
  }

  //运行xr-ay
  if (fs.existsSync(webPath)) {
    const command1 = `nohup ${webPath} -c ${configPath} >/dev/null 2>&1 &`;
    try {
      await exec(command1);
      console.log('xr-ay proxy service (web) is running');
      await new Promise((resolve) => setTimeout(resolve, 1000));
    } catch (error) {
      console.error(`xr-ay proxy service (web) running error: ${error}`);
    }
  } else {
    console.error("xr-ay proxy service executable 'web' not found. Proxy service will not start.");
  }

  // 运行cloud-fared
  if (fs.existsSync(botPath)) {
    let args;

    if (ARGO_AUTH && ARGO_DOMAIN) {
      // 用户指定了域名和认证（Token或JSON）
      if (ARGO_AUTH.match(/^[A-Z0-9a-z=]{120,250}$/)) {
        // Token认证
        args = `tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}`;
        console.log('Starting Cloudflare Tunnel with Token.');
      } else if (ARGO_AUTH.includes('TunnelSecret') && fs.existsSync(tunnelYmlPath)) {
        // JSON认证（tunnel.yml应该已由argoType创建）
        args = `tunnel --edge-ip-version auto --config ${tunnelYmlPath} run`;
        console.log('Starting Cloudflare Tunnel with JSON credentials file.');
      } else {
        console.warn('ARGO_AUTH specified but format not recognized as Token or JSON secret. Attempting temporary tunnel.');
        // 如果认证格式不正确但设置了域名，则回退到临时隧道
        args = `tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile ${bootLogPath} --loglevel info --url http://localhost:${ARGO_PORT}`;
        console.log('Starting Temporary Cloudflare Tunnel (fallback).');
      }
    } else {
      // 临时隧道（未指定域名/认证或只指定了一个）
      args = `tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile ${bootLogPath} --loglevel info --url http://localhost:${ARGO_PORT}`;
      console.log('Starting Temporary Cloudflare Tunnel.');
    }

    try {
      await exec(`nohup ${botPath} ${args} >/dev/null 2>&1 &`);
      console.log('Cloudflare Tunnel (bot) is starting...');
      await new Promise((resolve) => setTimeout(resolve, 4000)); // 增加延迟，让隧道有时间写入日志
    } catch (error) {
      console.error(`Error starting Cloudflare Tunnel (bot): ${error}`);
    }
  } else {
    console.warn("Cloudflare Tunnel executable 'bot' not found. Skipping tunnel start.");
  }

  await new Promise((resolve) => setTimeout(resolve, 5000));
}

//根据系统架构返回对应的url
function getFilesForArchitecture(architecture) {
  let baseFiles = [];
  console.log(`Determining files for architecture: ${architecture}`);

  // 代理服务 (web) 总是需要的
  const webUrl = architecture === 'arm'
    ? "https://arm64.ssss.nyc.mn/web"
    : "https://amd64.ssss.nyc.mn/web";
  baseFiles.push({ fileName: "web", fileUrl: webUrl });

  // Cloudflared (bot) 总是需要的
  const botUrl = architecture === 'arm'
    ? "https://arm64.ssss.nyc.mn/2go"
    : "https://amd64.ssss.nyc.mn/2go";
  baseFiles.push({ fileName: "bot", fileUrl: botUrl });

  // 哪吒探针仅在配置时下载
  if (NEZHA_SERVER && NEZHA_KEY) {
    if (NEZHA_PORT) { // 哪吒v0 (npm)
      const npmUrl = architecture === 'arm'
        ? "https://arm64.ssss.nyc.mn/agent"
        : "https://amd64.ssss.nyc.mn/agent";
      baseFiles.push({
        fileName: "npm",
        fileUrl: npmUrl
      });
    } else { // 哪吒v1 (php)
      const phpUrl = architecture === 'arm'
        ? "https://arm64.ssss.nyc.mn/v1"
        : "https://amd64.ssss.nyc.mn/v1";
      baseFiles.push({
        fileName: "php",
        fileUrl: phpUrl
      });
    }
  } else {
    console.log("Nezha agent download skipped (not configured).");
  }

  return baseFiles;
}

// 获取固定隧道json/yml
function argoType() {
  if (!ARGO_AUTH || !ARGO_DOMAIN) {
    console.log("ARGO_DOMAIN or ARGO_AUTH variable is empty/missing, will use temporary tunnel if needed.");
    return;
  }

  if (ARGO_AUTH.includes('TunnelSecret')) {
    console.log("ARGO_AUTH appears to be JSON secret. Generating tunnel.json and tunnel.yml");
    try {
      // 尝试解析JSON部分以获取隧道ID
      let tunnelID = "unknown-tunnel-id"; // 默认回退
      try {
        const parsedAuth = JSON.parse(ARGO_AUTH);
        tunnelID = parsedAuth.TunnelID || tunnelID;
      } catch (parseError) {
        console.warn("Could not parse ARGO_AUTH as JSON to extract TunnelID, using default in tunnel.yml");
        // 如果JSON解析失败，使用正则表达式作为不太可靠的回退
        const match = ARGO_AUTH.match(/"TunnelID":"([^"]+)"/);
        if (match && match[1]) {
          tunnelID = match[1];
        }
      }

      fs.writeFileSync(tunnelJsonPath, ARGO_AUTH);

      // 指向ARGO_PORT的入口
      const tunnelYaml = `
tunnel: ${tunnelID}
credentials-file: ${tunnelJsonPath}
protocol: http2

ingress:
  - hostname: ${ARGO_DOMAIN}
    service: http://localhost:${ARGO_PORT}
    originRequest:
       noTLSVerify: true # 如果本地服务使用自签名证书，保留此项
  - service: http_status:404 # 不匹配主机名的请求的默认回退
`;
      fs.writeFileSync(tunnelYmlPath, tunnelYaml);
      console.log(`Generated tunnel.yml for domain ${ARGO_DOMAIN} pointing to http://localhost:${ARGO_PORT}`);

    } catch (error) {
      console.error(`Error writing tunnel configuration files: ${error}`);
      // 清理可能损坏的文件
      fs.unlink(tunnelJsonPath, () => { });
      fs.unlink(tunnelYmlPath, () => { });
    }

  } else if (ARGO_AUTH.match(/^[A-Z0-9a-z=]{120,250}$/)) {
    console.log("ARGO_AUTH appears to be a Tunnel Token. Tunnel will be run directly with the token.");
    // token认证运行命令不需要tunnel.yml
    // 如果切换认证类型，清理任何旧的yml/json文件
    fs.unlink(tunnelJsonPath, () => { });
    fs.unlink(tunnelYmlPath, () => { });
  } else {
    console.warn("ARGO_AUTH format is unrecognized. Tunnel setup might rely on temporary tunnel logic.");
    // 如果认证格式错误，清理任何旧的yml/json文件
    fs.unlink(tunnelJsonPath, () => { });
    fs.unlink(tunnelYmlPath, () => { });
  }
}

// 获取隧道domain
async function extractDomains() {
  // 首先调用argoType生成tunnel.yml（如果需要）
  argoType();
  await new Promise(resolve => setTimeout(resolve, 100)); // 小延迟确保文件写入完成

  let argoDomain;

  if (ARGO_DOMAIN) {
    // 如果用户提供ARGO_DOMAIN，直接使用它（固定隧道）
    argoDomain = ARGO_DOMAIN;
    console.log(`Using specified fixed tunnel domain: ${argoDomain}`);
    await generateLinks(argoDomain);
  } else if (fs.existsSync(botPath)) {
    // 尝试从临时隧道日志中获取域名
    console.log('Attempting to extract temporary tunnel domain from boot log...');
    await new Promise(resolve => setTimeout(resolve, 5000)); // 等待更长时间让日志文件出现/填充

    try {
      if (!fs.existsSync(bootLogPath)) {
        console.log('boot.log not found. Cannot extract temporary domain. Tunnel might still be starting.');
        return; // 如果日志尚不存在，则退出函数
      }

      const fileContent = fs.readFileSync(bootLogPath, 'utf-8');
      const lines = fileContent.split('\n');
      const argoDomains = [];
      // 更新正则表达式以捕获不同的日志格式
      const domainRegex = /https:\/\/([a-zA-Z0-9-]+-[a-zA-Z0-9-]+\.trycloudflare\.com)/;

      lines.forEach((line) => {
        const domainMatch = line.match(domainRegex);
        if (domainMatch && domainMatch[1]) {
          const domain = domainMatch[1];
          // 仅添加唯一域名
          if (!argoDomains.includes(domain)) {
            argoDomains.push(domain);
          }
        }
      });

      if (argoDomains.length > 0) {
        argoDomain = argoDomains[argoDomains.length - 1]; // 获取找到的最新域名
        console.log(`Extracted temporary tunnel domain: ${argoDomain}`);
        await generateLinks(argoDomain);
      } else {
        console.log('Temporary tunnel domain not found in boot.log.');
      }
    } catch (error) {
      console.error('Error reading boot.log:', error);
    }
  } else {
    console.log("Cloudflared (bot) not found, cannot determine tunnel domain.");
  }

  // 生成 list 和 sub 信息
  async function generateLinks(argoDomain) {
    try {
      return new Promise((resolve) => {
        setTimeout(() => {
          const VMESS = { v: '2', ps: `${NAME}-vmess`, add: CFIP, port: CFPORT, id: UUID, aid: '0', scy: 'none', net: 'ws', type: 'none', host: argoDomain, path: '/vmess-argo?ed=2560', tls: 'tls', sni: argoDomain, alpn: '' };
          const subTxt = `
vless://${UUID}@${CFIP}:${CFPORT}?encryption=none&security=tls&sni=${argoDomain}&type=ws&host=${argoDomain}&path=%2Fvless-argo%3Fed%3D2560#${NAME}-vless

vmess://${Buffer.from(JSON.stringify(VMESS)).toString('base64')}

trojan://${UUID}@${CFIP}:${CFPORT}?security=tls&sni=${argoDomain}&type=ws&host=${argoDomain}&path=%2Ftrojan-argo%3Fed%3D2560#${NAME}-trojan
  `;
          // 打印 sub.txt 内容到控制台
          console.log('Generated subscription content:');
          console.log(Buffer.from(subTxt).toString('base64'));
          fs.writeFileSync(subPath, Buffer.from(subTxt).toString('base64'));
          console.log(`${FILE_PATH}/sub.txt saved successfully`);
          uploadNodes();
          // 将内容进行 base64 编码并写入 SUB_PATH 路由
          app.get(`/${SUB_PATH}`, (req, res) => {
            const encodedContent = Buffer.from(subTxt).toString('base64');
            res.set('Content-Type', 'text/plain; charset=utf-8');
            res.send(encodedContent);
          });
          resolve(subTxt);
        }, 2000);
      });
    } catch (error) {
      console.error(`Error generating links: ${error.message}`);
    }
  }
}

// 自动上传节点或订阅
async function uploadNodes() {
  if (UPLOAD_URL && PROJECT_URL) {
    const subscriptionUrl = `${PROJECT_URL}/${SUB_PATH}`;
    const jsonData = {
      subscription: [subscriptionUrl]
    };
    try {
      console.log(`Attempting to upload subscription: ${subscriptionUrl}`);
      const response = await axios.post(`${UPLOAD_URL}/api/add-subscriptions`, jsonData, {
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (response.status === 200) {
        console.log('Subscription uploaded successfully');
      } else {
        console.log(`Subscription upload returned status: ${response.status}`);
      }
    } catch (error) {
      if (error.response) {
        if (error.response.status === 400) {
          console.log('Subscription already exists');
        } else {
          console.error(`Subscription upload failed with status: ${error.response.status}`);
        }
      } else {
        console.error(`Subscription upload failed: ${error.message}`);
      }
    }
  } else if (UPLOAD_URL) {
    if (!fs.existsSync(subPath)) {
      console.log('No subscription file found to upload nodes');
      return;
    }

    try {
      const content = fs.readFileSync(subPath, 'utf-8');
      const decoded = Buffer.from(content, 'base64').toString('utf-8');
      const nodes = decoded.split('\n').filter(line =>
        /(vless|vmess|trojan|hysteria2|tuic):\/\//.test(line)
      );

      if (nodes.length === 0) {
        console.log('No valid nodes found in subscription file');
        return;
      }

      console.log(`Attempting to upload ${nodes.length} nodes`);
      const jsonData = JSON.stringify({ nodes });

      const response = await axios.post(`${UPLOAD_URL}/api/add-nodes`, jsonData, {
        headers: { 'Content-Type': 'application/json' }
      });

      if (response.status === 200) {
        console.log('Nodes uploaded successfully');
      } else {
        console.log(`Node upload returned status: ${response.status}`);
      }
    } catch (error) {
      console.error(`Node upload failed: ${error.message}`);
    }
  } else {
    console.log('Skipping upload nodes (UPLOAD_URL not configured)');
  }
}

// 自动访问项目URL
async function addVisitTask() {
  if (!AUTO_ACCESS || !PROJECT_URL) {
    console.log("Skipping automatic access task (not configured)");
    return;
  }

  try {
    console.log(`Adding automatic access task for URL: ${PROJECT_URL}`);
    const response = await axios.post('https://oooo.serv00.net/add-url', {
      url: PROJECT_URL
    }, {
      headers: {
        'Content-Type': 'application/json'
      }
    });
    console.log(`Automatic access task added successfully: ${response.data.message || 'Success'}`);
  } catch (error) {
    console.error(`Failed to add automatic access task: ${error.message}`);
  }
}

// 90s后删除相关文件
function cleanFiles() {
  setTimeout(() => {
    console.log('Starting scheduled cleanup of executables and logs...');
    // 保留配置文件，但清理二进制文件和日志
    const filesToDelete = [bootLogPath, webPath, botPath];

    // 有条件地添加哪吒探针文件
    if (NEZHA_SERVER && NEZHA_KEY) {
      if (NEZHA_PORT) {
        filesToDelete.push(npmPath);
      } else {
        filesToDelete.push(phpPath);
      }
    }

    // 使用rm -rf处理文件和可能的目录
    exec(`rm -rf ${filesToDelete.join(' ')}`, (error) => {
      if (error) {
        console.warn(`Cleanup command encountered an error: ${error.message}. Some files might remain.`);
      } else {
        console.log('Scheduled cleanup finished.');
      }
      console.log('-----------------------------------------------------');
      console.log('Proxy service with Nezha Agent and Cloudflare Tunnel setup complete.');
      console.log('Services should be running in the background.');
      console.log('-----------------------------------------------------');
    });
  }, 90000); // 90秒
}

// 主执行流程
async function startServer() {
  console.log("Starting script initialization...");

  // 生成xr-ay配置
  generateXrayConfig();

  // 删除旧节点
  await deleteNodes();

  // 清理旧文件
  cleanupOldFiles();

  // 下载并运行文件
  await downloadFilesAndRun();

  // 提取域名并生成链接
  await extractDomains();

  // 添加自动访问任务
  await addVisitTask();

  // 计划清理文件
  cleanFiles();

  console.log("Initialization sequence complete. Background services started.");
}

// 启动服务器进程
startServer().catch(err => {
  console.error("Critical error during startup sequence:", err);
});

// 保持express服务器运行
app.listen(PORT, () => console.log(`HTTP server listening on port: ${PORT}`));
