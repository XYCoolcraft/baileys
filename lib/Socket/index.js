import { DEFAULT_CONNECTION_CONFIG } from '../Defaults/index.js';
import { OptiMazer } from '../Utils/optimizer.js';
import { makeCommunitiesSocket } from './communities.js';
import { makeAIGroupsSocket } from './aigroups.js';
import { makeGraphQLSocket } from './graphql.js';
import { makeInteropSocket } from './interop.js';
import { makeManagedAccountSocket } from './managed-account.js';
import { makePrivacySocket } from './privacy.js';
import { makeRegistrationSocket } from './registration.js';
import { attachTextRouter } from './text-router.js';
// export the last socket layer
const makeWASocket = (config) => {
    const newConfig = {
        ...DEFAULT_CONNECTION_CONFIG,
        ...config
    };
    let sock = makeCommunitiesSocket(newConfig);
    // Extra first-party feature layers (account privacy/registration, Meta AI
    // groups, cross-app interop, GraphQL-based account/payments surface),
    // each a `sock => sock` wrapper adding methods on top of what's already
    // there — see LITERACY.md for what each one covers.
    sock = makeAIGroupsSocket(sock);
    sock = makePrivacySocket(sock);
    sock = makeRegistrationSocket(sock);
    sock = makeManagedAccountSocket(sock);
    sock = makeInteropSocket(sock);
    sock = makeGraphQLSocket(sock);
    // Optional convenience router: sock.onText/hears/command. Doesn't touch
    // anything unless you actually register a route.
    sock = attachTextRouter(sock);
    // optiMazer — opt-in resource-usage tuning, OFF unless `optiMazer` is set
    // (true or a config object). See lib/Utils/optimizer.js and README.md.
    if (newConfig.optiMazer) {
        const optimizerConfig = typeof newConfig.optiMazer === 'object' ? newConfig.optiMazer : {};
        const optimizer = new OptiMazer(optimizerConfig).attach(sock);
        sock = { ...sock, optiMazer: optimizer, getOptimizerStats: () => optimizer.getStats() };
    }
    return sock;
};
export default makeWASocket;
//# sourceMappingURL=index.js.map