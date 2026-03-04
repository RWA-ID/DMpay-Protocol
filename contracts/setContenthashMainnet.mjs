import { createWalletClient, http } from 'viem';
import { mainnet } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import { CID } from 'multiformats/cid';
import * as fs from 'fs';

const env = fs.readFileSync('.env', 'utf8');
const rpc = env.match(/MAINNET_RPC_URL=(.*)/)[1].trim();
const key = env.match(/MAINNET_PRIVATE_KEY=(.*)/)[1].trim();

const account = privateKeyToAccount('0x' + key);
const client = createWalletClient({ account, chain: mainnet, transport: http(rpc) });

const RESOLVER = '0xF29100983E058B709F3D539b0c765937B804AC15';
const DMPAY_NAMEHASH = '0x2059bd34c28c7a6645dd35be7e5dcc4b3e4999849bbe8b2c8b838f2d4cfc3ec8';
const CID_STR = 'bafybeia7b7ynzjangortbzpcwzs2br7cherd7flqfqrfkshbak2qzpzela';

const cid = CID.parse(CID_STR);
const cidBytes = cid.bytes;
const prefix = new Uint8Array([0xe3, 0x01]);
const contenthash = new Uint8Array(prefix.length + cidBytes.length);
contenthash.set(prefix, 0);
contenthash.set(cidBytes, prefix.length);
const contenthashHex = '0x' + Buffer.from(contenthash).toString('hex');
console.log('Contenthash:', contenthashHex);

const abi = [{ name: 'setContenthash', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'node', type: 'bytes32' }, { name: 'hash', type: 'bytes' }], outputs: [] }];

const tx = await client.writeContract({ address: RESOLVER, abi, functionName: 'setContenthash', args: [DMPAY_NAMEHASH, contenthashHex] });
console.log('Contenthash set on mainnet! tx:', tx);
