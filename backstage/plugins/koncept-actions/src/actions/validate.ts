import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';
import { executeKoncept } from '../lib/executor';

/**
 * Scaffolder action: koncept:validate
 *
 * Validates KCL configurations by compiling factory_seed.k.
 * Catches schema errors before rendering.
 * Uses the Go CLI's `--factory` flag from the workspace root.
 */
export function konceptValidateAction() {
    return createTemplateAction({
        id: 'koncept:validate',
        description: 'Validate KCL configurations using the koncept CLI',
        schema: {
            input: z.object({
                factoryDir: z
                    .string()
                    .optional()
                    .describe('Path to factory directory (defaults to ./factory)'),
            }),
            output: z.object({
                valid: z.boolean().describe('Whether the configuration is valid'),
                errors: z
                    .string()
                    .optional()
                    .describe('Validation error messages if invalid'),
            }),
        },
        async handler(ctx) {
            const { factoryDir } = ctx.input;
            const args = ['validate'];
            if (factoryDir) {
                args.push('--factory', factoryDir);
            }

            ctx.logger.info(
                `Validating KCL configurations in ${factoryDir || './factory'}`,
            );

            const result = await executeKoncept(args, {
                cwd: ctx.workspacePath,
                logger: ctx.logger,
            });

            const valid = result.exitCode === 0;
            ctx.output('valid', valid);
            if (!valid) {
                ctx.output('errors', result.stderr);
            }

            ctx.logger.info(
                valid
                    ? 'Configuration is valid'
                    : `Validation failed: ${result.stderr}`,
            );
        },
    });
}
