// WSL-related downloads for rancher-desktop development.
// Note that this does _not_ include installing WSL on the machine.

import fs from 'fs';
import os from 'os';
import path from 'path';

import { download } from '../lib/download.mjs';

export default async function main() {
  const v = '0.20';

  await download(
    `https://github.com/rancher-sandbox/rancher-desktop-wsl-distro/releases/download/v${ v }/distro-${ v }.tar`,
    path.resolve(process.cwd(), 'resources', os.platform(), `distro-${ v }.tar`),
    { access: fs.constants.W_OK });

  // Download host-resolver
  // TODO(@Nino-k) once host-resolver stabilizes remove and add to wsl-distro
  // resolver-0.1.0-beta2-windows-amd64.zip
  const hostResolverVersion = '0.1.0-beta2'
  // download vsock-host
  await download(
    `https://github.com/Nino-K/rancher-desktop-host-resolver/releases/download/${ v }/resolver-${ v }-windows-amd64.zip`,
    path.resolve(process.cwd(), 'resources', os.platform(), `resolver-${ v }-windows-amd64.tar`),
    { access: fs.constants.W_OK });

  // download vsock-peer
  await download(
    `https://github.com/Nino-K/rancher-desktop-host-resolver/releases/download/${ v }/resolver-${ v }-linux-amd64.zip`,
    path.resolve(process.cwd(), 'resources', os.platform(), `resolver-${ v }-linux-amd64.tar`),
    { access: fs.constants.W_OK });
}
