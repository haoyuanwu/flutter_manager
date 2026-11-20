import { test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

test('bundled server advertises tools and forwards build/upload parameters to authenticated bridge', async () => {
  const requests = [];
  const bridge = http.createServer(async (req, res) => {
    let body = '';
    for await (const part of req) body += part;
    requests.push({path: req.url, authorization: req.headers.authorization, args: JSON.parse(body)});
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ok: true, accepted: true, operationId: 'mcp-1', status: 'running'}));
  });
  await new Promise(resolve => bridge.listen(0, '127.0.0.1', resolve));
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [fileURLToPath(new URL('../dist/flutter-manager-mcp.mjs', import.meta.url))],
    env: {...process.env, FLUTTER_MANAGER_PORT: String(bridge.address().port), FLUTTER_MANAGER_TOKEN: 'test-token'},
  });
  const client = new Client({name: 'api-test', version: '1'}, {capabilities: {}});
  try {
    await client.connect(transport);
    const {tools} = await client.listTools();
    assert.equal(new Set(tools.map(t => t.name)).size, tools.length);
    for (const name of ['get_operation','package_macos','package_windows','scan_artifacts','upload_pgyer','upload_fir','sign_apk','install_apk','configure_project','get_capabilities','dependencies']) {
      assert.ok(tools.some(t => t.name === `flutter_manager_${name}`));
    }
    const build = {projectPath:'/demo', target:'apk', mode:'release', flavors:['prod']};
    const result = await client.callTool({name:'flutter_manager_build', arguments:build});
    assert.equal(JSON.parse(result.content[0].text).status, 'running');
    await client.callTool({name:'flutter_manager_upload_fir', arguments:{projectPath:'/demo', filePath:'/demo/app.apk'}});
    assert.deepEqual(requests[0], {path:'/tools/build', authorization:'Bearer test-token', args:build});
    assert.equal(requests[1].path, '/tools/upload_fir');
    assert.equal(requests[1].args.filePath, '/demo/app.apk');
    await assert.rejects(client.callTool({name:'flutter_manager_nonexistent', arguments:{}}));
  } finally {
    await client.close();
    await new Promise(resolve => bridge.close(resolve));
  }
});
