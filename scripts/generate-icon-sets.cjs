#!/usr/bin/env node
// Offline exporter for the accepted artwork. Requires Node.js and sharp 0.35.5.
// It writes only Artwork/IconSets; it never replaces application assets.
'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'Artwork/IconSets');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const files = [];
async function write(relative, data) {
  const filename = path.join(output, relative);
  await fs.mkdir(path.dirname(filename), {recursive:true});
  await fs.writeFile(filename, data);
  files.push(relative);
}
const json = value => JSON.stringify(value, null, 2) + '\n';
const sizes = [16,32,128,256,512];
const sets = [
  {id:'mask',name:'Mask',nameUk:'Маска',asset:'MenuMask',source:'Artwork/Studies/menu-mask-geometric.svg'},
  {id:'balloon',name:'Balloon',nameUk:'Куля',asset:'MenuBalloon',source:'Artwork/Studies/Balloon/balloon-compact.svg'}
];

async function main() {
  const paletteFile = await fs.readFile(path.join(output,'palettes.json'));
  const paletteCatalog = JSON.parse(paletteFile);
  const palettes = paletteCatalog.palettes;
  const manifest = {
    schemaVersion:1, approvedGeometryDate:'2026-10-16',
    approval:paletteCatalog.approval,
    scope:'Prepared assets only; menu bar and Dock selection are not implemented.',
    renderer:{sharp:sharp.versions.sharp,librsvg:sharp.versions.rsvg},
    palettes:'palettes.json', sets:[]
  };
  for (const set of sets) {
    const source = await fs.readFile(path.join(root,set.source));
    const svg = source.toString();
    const inner = svg.replace(/^<svg\b[^>]*>/,'').replace(/<\/svg>\s*$/,'');
    const paint = inner.replace(/<title>.*?<\/title>/s,'').replace(/<desc>.*?<\/desc>/s,'');
    await write(`${set.id}/symbol.svg`,source);
    const item = {
      id:set.id,name:set.name,nameUk:set.nameUk,
      source:set.source,sourceSHA256:sha(source),symbol:`${set.id}/symbol.svg`,
      menuBar:{assetName:set.asset,logicalSize:16,viewBox:[-1,-2,34,34],isTemplate:true,imageset:`${set.id}/menubar/${set.asset}.imageset`,svg:`${set.id}/menubar/template.svg`},
      dock:[]
    };
    const menuSVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-1 -2 34 34" width="16" height="16" color="#000000"><title>${set.name} menu bar template</title>${paint}</svg>\n`;
    await write(item.menuBar.svg,menuSVG);
    for (const scale of [1,2]) {
      const pixels=16*scale;
      const image = await sharp(Buffer.from(menuSVG),{density:288}).resize(pixels,pixels).png().toBuffer();
      await write(`${item.menuBar.imageset}/menuIcon${scale===2?'@2x':''}.png`,image);
    }
    await write(`${item.menuBar.imageset}/Contents.json`,json({images:[
      {filename:'menuIcon.png',idiom:'universal',scale:'1x'},
      {filename:'menuIcon@2x.png',idiom:'universal',scale:'2x'}
    ],info:{author:'xcode',version:1},properties:{'template-rendering-intent':'template'}}));
    for (const palette of palettes) {
      const dir = `${set.id}/dock/${palette.id}`;
      const gradient = palette.backgroundGradient;
      const sky = gradient ? `<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">${gradient.map(stop => `<stop offset="${stop.offset}" stop-color="${stop.color}"/>`).join('')}</linearGradient></defs>` : '';
      const background = gradient ? 'url(#sky)' : palette.background;
      const appSVG = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><title>Gas Mask NG — ${set.name}, ${palette.name}</title>${sky}<rect x="82" y="82" width="860" height="860" rx="190" fill="${background}"/><g transform="translate(205 205) scale(19.1875)" color="${palette.symbol}" fill="currentColor">${paint}</g></svg>\n`;
      await write(`${dir}/icon.svg`,appSVG);
      const master = await sharp(Buffer.from(appSVG)).png().toBuffer();
      await write(`${dir}/icon.png`,master);
      const catalog = {images:[],info:{author:'xcode',version:1}};
      const temp = await fs.mkdtemp(path.join(os.tmpdir(),'gasmask-icon-set-'));
      const iconset = path.join(temp,'icon.iconset');
      await fs.mkdir(iconset);
      try {
        const buffers = new Map([[1024,master]]);
        for (const size of sizes) for (const scale of [1,2]) {
          const pixels=size*scale;
          if (!buffers.has(pixels)) buffers.set(pixels,await sharp(master).resize(pixels,pixels).png().toBuffer());
          const filename=`icon_${size}x${size}${scale===2?'@2x':''}.png`;
          await write(`${dir}/AppIcon.appiconset/${filename}`,buffers.get(pixels));
          await fs.writeFile(path.join(iconset,filename),buffers.get(pixels));
          catalog.images.push({filename,idiom:'mac',scale:`${scale}x`,size:`${size}x${size}`});
        }
        await write(`${dir}/AppIcon.appiconset/Contents.json`,json(catalog));
        execFileSync('/usr/bin/iconutil',['-c','icns','-o',path.join(temp,'icon.icns'),iconset]);
        await write(`${dir}/icon.icns`,await fs.readFile(path.join(temp,'icon.icns')));
      } finally {
        await fs.rm(temp,{recursive:true,force:true});
      }
      item.dock.push({palette:palette.id,svg:`${dir}/icon.svg`,png:`${dir}/icon.png`,icns:`${dir}/icon.icns`,assetCatalog:`${dir}/AppIcon.appiconset`});
    }
    manifest.sets.push(item);
  }
  await write('manifest.json',json(manifest));
  files.push('palettes.json');
  const sums=[];
  for (const file of files.sort()) sums.push(`${sha(await fs.readFile(path.join(output,file)))}  ${file}`);
  await write('SHA256SUMS',sums.join('\n')+'\n');
  process.stdout.write(`Exported ${sets.length} sets, ${palettes.length} palettes each, with menu templates, Dock PNG/SVG/ICNS and Xcode catalogs.\n`);
}
main().catch(error => { process.stderr.write(error.stack+'\n');process.exitCode=1; });
