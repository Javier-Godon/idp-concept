import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';
import { executeKoncept } from '../lib/executor';

/**
 * Scaffolder action: koncept:publish
 *
 * Publishes a KCL module to an OCI registry using `koncept publish`.
 * Wraps `kcl mod push` with proper version tagging.
 */
export function konceptPublishAction() {
    return createTemplateAction({
        id: 'koncept:publish',
        description: 'Publish a KCL module to an OCI registry',
        schema: {
            input: z.object({
                modulePath: z
                    .string()
                    .describe('Path to the KCL module directory'),
                version: z
                    .string()
                    .regex(/^\d+\.\d+\.\d+$/, 'Version must be semver (e.g., 1.0.0)')
                    .describe('Semantic version tag for the module'),
            }),
            output: z.object({
                published: z.boolean().describe('Whether the module was published'),
            }),
        },
        async handler(ctx) {
            const { modulePath, version } = ctx.input;
            const moduleDir = `${ctx.workspacePath}/${modulePath}`;

            ctx.logger.info(
                `Publishing KCL module from ${moduleDir} as version ${version}`,
            );

            const result = await executeKoncept(
                ['publish', modulePath, '--output', version],
                {
                    cwd: ctx.workspacePath,
                    logger: ctx.logger,
                },
            );

            const published = result.exitCode === 0;
            ctx.output('published', published);

            ctx.logger.info(
                published
                    ? `Published module version ${version}`
                    : `Publish failed: ${result.stderr}`,
            );
        },
    });
}
