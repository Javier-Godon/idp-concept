import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';
import { executeKoncept } from '../lib/executor';

const TEMPLATE_TYPES = [
    'webapp',
    'database',
    'kafka',
    'postgresql',
    'mongodb',
    'rabbitmq',
    'redis',
    'keycloak',
    'opensearch',
    'vault',
    'questdb',
    'minio',
] as const;

/**
 * Scaffolder action: koncept:init
 *
 * Scaffolds a new project, release, or module using the koncept CLI.
 * Creates the factory directory structure with render.k and factory_seed.k.
 */
export function konceptInitAction() {
    return createTemplateAction({
        id: 'koncept:init',
        description:
            'Initialize a new KCL project/release using the koncept CLI',
        schema: {
            input: z.object({
                template: z
                    .enum(TEMPLATE_TYPES)
                    .optional()
                    .describe('KCL template type to scaffold'),
                name: z.string().describe('Name of the module/project to create'),
                namespace: z
                    .string()
                    .optional()
                    .default('default')
                    .describe('Kubernetes namespace'),
                projectDir: z
                    .string()
                    .optional()
                    .describe('Target project directory (defaults to workspace root)'),
            }),
            output: z.object({
                projectDir: z.string().describe('Directory where project was created'),
            }),
        },
        async handler(ctx) {
            const { template, name, namespace, projectDir } = ctx.input;
            const targetDir = projectDir || ctx.workspacePath;

            const args = ['init', '--name', name];
            if (template) {
                args.push('--template', template);
            }
            if (namespace) {
                args.push('--namespace', namespace);
            }

            ctx.logger.info(
                `Initializing ${template || 'project'} "${name}" in ${targetDir}`,
            );

            await executeKoncept(args, {
                cwd: targetDir,
                logger: ctx.logger,
            });

            ctx.output('projectDir', targetDir);

            ctx.logger.info(`Initialized ${template || 'project'} "${name}"`);
        },
    });
}
