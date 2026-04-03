import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';
import { executeKoncept } from '../lib/executor';

const SUPPORTED_OUTPUTS = [
    'yaml',
    'argocd',
    'helmfile',
    'helm',
    'kusion',
    'kustomize',
    'timoni',
    'crossplane',
    'backstage',
] as const;

/**
 * Scaffolder action: koncept:render
 *
 * Renders KCL manifests in the specified output format using the koncept CLI.
 * Delegates to `koncept render <output>` inside the workspace directory.
 */
export function konceptRenderAction() {
    return createTemplateAction({
        id: 'koncept:render',
        description: 'Render KCL manifests using the koncept CLI',
        schema: {
            input: z.object({
                output: z.enum(SUPPORTED_OUTPUTS).describe(
                    'Output format: yaml, argocd, helmfile, helm, kusion, kustomize, timoni, crossplane, backstage',
                ),
                factoryDir: z
                    .string()
                    .optional()
                    .describe('Path to factory directory (defaults to ./factory)'),
            }),
            output: z.object({
                outputDir: z
                    .string()
                    .describe('Directory where rendered manifests were written'),
            }),
        },
        async handler(ctx) {
            const { output, factoryDir } = ctx.input;
            const workDir = factoryDir
                ? `${ctx.workspacePath}/${factoryDir}`
                : `${ctx.workspacePath}/factory`;

            ctx.logger.info(`Rendering ${output} manifests from ${workDir}`);

            const result = await executeKoncept(['render', output], {
                cwd: workDir,
                logger: ctx.logger,
            });

            const outputDir = `${workDir}/output/${output}`;
            ctx.output('outputDir', outputDir);

            ctx.logger.info(
                `Rendered ${output} manifests to ${outputDir} (exit code: ${result.exitCode})`,
            );
        },
    });
}
