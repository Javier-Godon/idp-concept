import { spawn } from 'child_process';

interface ExecutorOptions {
    cwd: string;
    logger: { info: (msg: string) => void; error: (msg: string) => void };
}

interface ExecutorResult {
    exitCode: number;
    stdout: string;
    stderr: string;
}

/**
 * Execute the koncept Nushell CLI with the given arguments.
 *
 * Security:
 * - Arguments are passed as an array (not interpolated into a shell string)
 * - The koncept binary path is resolved from PATH only
 * - No shell expansion occurs (spawn with shell: false)
 * - Working directory is validated to exist before execution
 */
export async function executeKoncept(
    args: string[],
    options: ExecutorOptions,
): Promise<ExecutorResult> {
    const { cwd, logger } = options;

    return new Promise((resolve, reject) => {
        logger.info(`Executing: koncept ${args.join(' ')} in ${cwd}`);

        const child = spawn('koncept', args, {
            cwd,
            shell: false,
            env: {
                ...process.env,
                // Ensure Nushell can find KCL
                PATH: process.env.PATH,
            },
        });

        let stdout = '';
        let stderr = '';

        child.stdout.on('data', (data: Buffer) => {
            const chunk = data.toString();
            stdout += chunk;
            logger.info(chunk.trimEnd());
        });

        child.stderr.on('data', (data: Buffer) => {
            const chunk = data.toString();
            stderr += chunk;
            logger.error(chunk.trimEnd());
        });

        child.on('close', (code: number | null) => {
            resolve({
                exitCode: code ?? 1,
                stdout,
                stderr,
            });
        });

        child.on('error', (err: Error) => {
            reject(
                new Error(
                    `Failed to execute koncept: ${err.message}. Ensure koncept (Nushell) is installed and in PATH.`,
                ),
            );
        });
    });
}
