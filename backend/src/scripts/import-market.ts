import dotenv from 'dotenv';
import { importMarketPrices } from '#market/market-import';

// Manual run of the DA Bantay Presyo import. The server schedules the same
// thing daily; this is for a first fill, a re-run after a failure, or a
// quick check on one region:
//   npm run import:market
//   npm run import:market -- --regions=NCR,Region III --categories=7,9
dotenv.config();

const arg = (name: string): string | undefined =>
    process.argv.find((a) => a.startsWith(`--${name}=`))?.slice(name.length + 3);

const regions = arg('regions')?.split(',').map((r) => r.trim()).filter(Boolean);
const categories = arg('categories')?.split(',').map(Number).filter((n) => Number.isInteger(n));

importMarketPrices({ regions, categories, log: console.log })
    .then((summary) => {
        console.log(JSON.stringify(summary, null, 2));
        process.exit(summary.tables === 0 ? 1 : 0);
    })
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
