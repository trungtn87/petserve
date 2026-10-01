import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const code = await readFile(new URL('./src/index.js', import.meta.url), 'utf8');
const { default: worker } = await import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'));
let calls = 0;
let referenceSeen = false;
const env = { PETVERSE_PROXY_KEY: 'test-key', AI: { async run(model, input) {
  calls++;
  const form = await new Response(input.multipart.body, {headers:{'content-type':input.multipart.contentType}}).formData();
  referenceSeen = form.has('input_image_0');
  assert.equal(form.get('prompt'), 'test');
  return {image:'mock-image'};
}}};
async function send(path, body, key='test-key') {
 return worker.fetch(new Request('https://test.local/v1/render/'+path, {method:'POST',headers:{'content-type':'application/json','X-PetVerse-Key':key},body:JSON.stringify(body)}),env);
}
assert.equal((await send('initial',{prompt:'test'})).status,200);
assert.equal(referenceSeen,false);
assert.equal((await send('evolution',{prompt:'test'})).status,400);
assert.equal((await send('evolution',{prompt:'test',source_image:'bad'})).status,400);
assert.equal((await send('initial',{prompt:'test'},'wrong')).status,401);
const png = Buffer.alloc(24); png.set([137,80,78,71,13,10,26,10]);png.writeUInt32BE(288,16);png.writeUInt32BE(511,20);
assert.equal((await send('evolution',{prompt:'test',source_image:png.toString('base64')})).status,200);
assert.equal(referenceSeen,true);
png.writeUInt32BE(512,20);
assert.equal((await send('evolution',{prompt:'test',source_image:png.toString('base64')})).status,400);
assert.equal(calls,2);
console.log('Worker contract PASS: initial, reference edit, validation, auth, provider call count');
