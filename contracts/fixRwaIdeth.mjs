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
const ENS_REGISTRY = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';

// namehash for rwa-ideth.dmpay.eth
const { namehash, labelhash } = await import('viem/ens');
const DMPAY_NODE = '0x2059bd34c28c7a6645dd35be7e5dcc4b3e4999849bbe8b2c8b838f2d4cfc3ec8';
const LABEL = labelhash('rwa-ideth');
const SUBNODE = namehash('rwa-ideth.dmpay.eth');
console.log('Subnode:', SUBNODE);

const CID_STR = 'bafkreia2cyytomn2enuoxb4wqq2yjhybuxrqotdcpdqbwzzvk3lbt4pnhm';
const cid = CID.parse(CID_STR);
const cidBytes = cid.bytes;
const prefix = new Uint8Array([0xe3, 0x01]);
const contenthash = new Uint8Array(prefix.length + cidBytes.length);
contenthash.set(prefix, 0);
contenthash.set(cidBytes, prefix.length);
const contenthashHex = '0x' + Buffer.from(contenthash).toString('hex');

const registryAbi = [
  { name: 'setSubnodeRecord', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'node', type: 'bytes32' }, { name: 'label', type: 'bytes32' }, { name: 'owner', type: 'address' }, { name: 'resolver', type: 'address' }, { name: 'ttl', type: 'uint64' }], outputs: [] }
];

const resolverAbi = [
  { name: 'setContenthash', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'node', type: 'bytes32' }, { name: 'hash', type: 'bytes' }], outputs: [] },
  { name: 'setAddr', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'node', type: 'bytes32' }, { name: 'addr', type: 'address' }], outputs: [] }
];

const USER_WALLET = '0x0104c88Ea4f55c26df89F5cd3eC62F3C8288D69b';

console.log('Setting subnode record...');
const tx1 = await client.writeContract({
  address: ENS_REGISTRY,
  abi: registryAbi,
  functionName: 'setSubnodeRecord',
  args: [DMPAY_NODE, LABEL, USER_WALLET, RESOLVER, 0n]
});
console.log('Subnode record set! tx:', tx1);

await new Promise(r => setTimeout(r, 5000));

console.log('Setting contenthash...');
const tx2 = await client.writeContract({
  address: RESOLVER,
  abi: resolverAbi,
  functionName: 'setContenthash',
  args: [SUBNODE, contenthashHex]
});
console.log('Contenthash set! tx:', tx2);

console.log('Setting address...');
const tx3 = await client.writeContract({
  address: RESOLVER,
  abi: resolverAbi,
  functionName: 'setAddr',
  args: [SUBNODE, USER_WALLET]
});
console.log('Address set! tx:', tx3);
console.log('Done! Visit: https://rwa-ideth.dmpay.eth.limo');
