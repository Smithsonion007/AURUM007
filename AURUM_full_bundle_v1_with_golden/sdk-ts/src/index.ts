import { createHash } from 'blake3';
export function blake3ds(dst: string, bytes: Uint8Array): Uint8Array {
  const key = createHash().update(new TextEncoder().encode(dst)).digest();
  const h = createHash({ key }); h.update(bytes); return h.digest();
}
export function hex(u8: Uint8Array): string { return [...u8].map(b=>b.toString(16).padStart(2,'0')).join(''); }
export function txId(bytes: Uint8Array): string { return hex(blake3ds('AURUM/Tx', bytes)); }
