import makeWASocket from './Socket/index.js';
import chalk from "chalk";
console.log(chalk.hex("#a855f7")(`
██╗  ██╗██╗   ██╗ ██████╗ ██████╗  ██████╗ ██╗      ██████╗██████╗  █████╗ ███████╗████████╗
╚██╗██╔╝╚██╗ ██╔╝██╔════╝██╔═══██╗██╔═══██╗██║     ██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝
 ╚███╔╝  ╚████╔╝ ██║     ██║   ██║██║   ██║██║     ██║     ██████╔╝███████║█████╗     ██║
 ██╔██╗   ╚██╔╝  ██║     ██║   ██║██║   ██║██║     ██║     ██╔══██╗██╔══██║██╔══╝     ██║
██╔╝ ██╗   ██║   ╚██████╗╚██████╔╝╚██████╔╝███████╗╚██████╗██║  ██║██║  ██║██║        ██║
╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═════╝  ╚═════╝ ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝
`));
console.log(chalk.hex("#a855f7")("@xayz/baileys — XYCoolcraft's WhatsApp library.\nThanks You For Using."));
console.log(chalk.gray("Modified Baileys By: @XYCoolcraft\n"));
export * from '../WAProto/index.js';
export * from './Utils/index.js';
export * from './Types/index.js';
export * from './Defaults/index.js';
export * from './WABinary/index.js';
export * from './WAM/index.js';
export * from './WAUSync/index.js';
export * from './Store/index.js';
export { makeWASocket };
export default makeWASocket;
//# sourceMappingURL=index.js.map