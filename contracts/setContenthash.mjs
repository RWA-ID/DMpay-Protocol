import { createWalletClient, http } from 'viem';
import { sepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import { CID } from 'multiformats/cid';
import * as fs from 'fs';

const env = fs.readFileSync('.env', 'utf8');
const rpc = env.match(/SEPOLIA_RPC_URL=(.*)/)[1].trim();
const key = env.match(/SEPOLIA_PRIVATE_KEY=(.*)/)[1].trim();

const account = privateKeyToAccount('0x' + key);
const client = createWalletClient({ account, chain: sepolia, transport: http(rpc) });

const RESOLVER = '0xE99638b40E4Fff0129D56f03b55b6bbC4BBE49b5';
const DMPAY_NAMEHASH = '0x2059bd34c28c7a6645dd35be7e5dcc4b3e4999849bbe8b2c8b838f2d4cfc3ec8';
const CID_STR = 'bafybeiajcuxb7kgtvhyyo3kiu2lotniz247l3zkfjxvoywomdefpezgcye';

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
console.log('Contenthash set! tx:', tx);
