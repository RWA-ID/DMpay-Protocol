import { createWalletClient, http } from 'viem';
import { mainnet } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import * as fs from 'fs';

const env = fs.readFileSync('.env', 'utf8');
const rpc = env.match(/MAINNET_RPC_URL=(.*)/)[1].trim();
const key = env.match(/MAINNET_PRIVATE_KEY=(.*)/)[1].trim();

const account = privateKeyToAccount('0x' + key);
const client = createWalletClient({ account, chain: mainnet, transport: http(rpc) });

const RESOLVER = '0xF29100983E058B709F3D539b0c765937B804AC15';
const SUBDOMAIN_HASH = '0xa8d9d2de1091fe47a5475b32d4243c50a919918f0e20ca8cba5491595d263136';
const CID = 'bafkreidoxdlkwvbayzhho5jyyjjjfhzi5yak264awwtddjusgx6izkgonm';

const { CID: CIDClass } = await import('multiformats/cid');
const cid = CIDClass.parse(CID);
const cidBytes = cid.bytes;
const prefix = new Uint8Array([0xe3, 0x01]);
const contenthash = new Uint8Array(prefix.length + cidBytes.length);
contenthash.set(prefix, 0);
contenthash.set(cidBytes, prefix.length);
const contenthashHex = '0x' + Buffer.from(contenthash).toString('hex');

const resolverAbi = [{ name: 'setContenthash', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'node', type: 'bytes32' }, { name: 'hash', type: 'bytes' }], outputs: [] }];

console.log('Setting contenthash for ensgianteth.dmpay.eth...');
const tx = await client.writeContract({ 
  address: RESOLVER, 
  abi: resolverAbi, 
  functionName: 'setContenthash', 
  args: [SUBDOMAIN_HASH, contenthashHex] 
});
console.log('Done! tx:', tx);
console.log('Visit: https://ensgianteth.dmpay.eth.limo');
