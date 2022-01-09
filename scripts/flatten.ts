import fs from 'fs';
import hre from 'hardhat';
import path from 'path';

export const CONTRACT_FILE = 'ERC721ExchangeUpgradeable.sol';
export const SDPX_LICENSE = 'BSD-3-Clause';
export const OUT_DIR = path.join(__dirname, '..', 'dist');

export async function flattenWithMetadata(taskArgs: { file: string; license: string; output: string }) {
	let flat = '';
	const originalStdoutWrite = process.stdout.write.bind(process.stdout);

	// @ts-expect-error Magic
	process.stdout.write = (chunk) => {
		if (typeof chunk === 'string') {
			flat += chunk;
		}
	};

	await hre.run('flatten', {
		files: [path.join(__dirname, '..', 'contracts', taskArgs.file)]
	});

	process.stdout.write = originalStdoutWrite;

	const outLines = flat
		.replace(/\/\/ SPDX-License-Identifier: (.*)/gi, (_, p1) => `// ${p1}`)
		.replace(/\/\/ File .*/gi, '')
		.replace(/\n\n\n\n/gi, '')
		.split('\n');
	outLines.splice(0, 0, `// SPDX-License-Identifier: ${taskArgs.license}`);
	outLines.splice(1, 1);

	const out = outLines.join('\n');

	fs.mkdirSync(taskArgs.output, { recursive: true });
	fs.writeFileSync(path.join(taskArgs.output, `Flat${taskArgs.file}`), out);
}

void flattenWithMetadata({ file: CONTRACT_FILE, license: SDPX_LICENSE, output: OUT_DIR }).catch((error) => {
	console.error(error);
	process.exit(1);
});
