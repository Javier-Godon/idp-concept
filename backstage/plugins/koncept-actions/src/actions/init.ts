import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';
import { executeKoncept } from '../lib/executor';

const TEMPLATE_TYPES = [
    'webapp',
    'database',
    'kafka',
    'postgres',
    'postgresql',
    'mongodb',
    'rabbitmq',
    'redis',
] as const;

const INIT_KINDS = ['project', 'module', 'env', 'release', 'factory'] as const;

function cliModuleType(moduleType: (typeof TEMPLATE_TYPES)[number]) {
    return moduleType === 'postgresql' ? 'postgres' : moduleType;
}

function pushFlag(
    args: string[],
    name: string,
    value: string | number | undefined,
) {
    if (value !== undefined && value !== '') {
        args.push(name, String(value));
    }
}

/**
 * Scaffolder action: koncept:init
 *
 * Scaffolds a project, module, environment, release, or factory using the
 * same Go CLI subcommands documented for local developer workflows.
 */
export function konceptInitAction() {
    return createTemplateAction({
        id: 'koncept:init',
        description:
            'Initialize idp-concept project lifecycle artifacts using the koncept CLI',
        schema: {
            input: z.object({
                kind: z
                    .enum(INIT_KINDS)
                    .optional()
                    .describe(
                        'What to scaffold: project, module, env, release, or factory. Defaults to module when template is set, otherwise project.',
                    ),
                template: z
                    .enum(TEMPLATE_TYPES)
                    .optional()
                    .describe(
                        'Module template type. Kept for existing Backstage templates; equivalent to moduleType.',
                    ),
                moduleType: z
                    .enum(TEMPLATE_TYPES)
                    .optional()
                    .describe('Module template type for kind=module'),
                name: z
                    .string()
                    .describe('Project name, module name, environment name, or release version'),
                namespace: z
                    .string()
                    .optional()
                    .describe('Kubernetes namespace for module/env scaffolding'),
                projectDir: z
                    .string()
                    .optional()
                    .describe('Existing project root for module/env/release scaffolding'),
                dest: z
                    .string()
                    .optional()
                    .describe('Destination root for kind=project (defaults to projects)'),
                factoryDir: z
                    .string()
                    .optional()
                    .describe('Factory directory for kind=factory (defaults to ./factory)'),
                frameworkPath: z
                    .string()
                    .optional()
                    .describe('Framework path for kind=project'),
                gitRepo: z
                    .string()
                    .optional()
                    .describe('Git repository URL for kind=project'),
                image: z
                    .string()
                    .optional()
                    .describe('Container image for project/module scaffolding'),
                version: z
                    .string()
                    .optional()
                    .describe('Image or release version'),
                port: z.number().int().positive().optional().describe('Service port'),
                owner: z
                    .string()
                    .optional()
                    .describe('Backstage owner for kind=project'),
                storage: z
                    .string()
                    .optional()
                    .describe('Storage size for stateful module scaffolding'),
                storageClass: z
                    .string()
                    .optional()
                    .describe('StorageClass for env/release scaffolding'),
            }),
            output: z.object({
                workDir: z.string().describe('Directory where koncept was executed'),
            }),
        },
        async handler(ctx) {
            const {
                kind,
                template,
                moduleType,
                name,
                namespace,
                projectDir,
                dest,
                factoryDir,
                frameworkPath,
                gitRepo,
                image,
                version,
                port,
                owner,
                storage,
                storageClass,
            } = ctx.input;
            const initKind = kind || (template || moduleType ? 'module' : 'project');
            const targetDir = projectDir
                ? `${ctx.workspacePath}/${projectDir}`
                : ctx.workspacePath;

            const args = ['init'];
            let workDir = targetDir;

            if (initKind === 'project') {
                args.push('project', name);
                pushFlag(args, '--dest', dest);
                pushFlag(args, '--framework-path', frameworkPath);
                pushFlag(args, '--git-repo', gitRepo);
                pushFlag(args, '--image', image);
                pushFlag(args, '--version', version);
                pushFlag(args, '--port', port);
                pushFlag(args, '--owner', owner);
            } else if (initKind === 'module') {
                const selectedModuleType = moduleType || template;
                if (!selectedModuleType) {
                    throw new Error('koncept:init kind=module requires moduleType or template');
                }
                args.push('module', cliModuleType(selectedModuleType), name);
                pushFlag(args, '--project', projectDir ? targetDir : undefined);
                pushFlag(args, '--image', image);
                pushFlag(args, '--version', version);
                pushFlag(args, '--port', port);
                pushFlag(args, '--storage', storage);
            } else if (initKind === 'env') {
                args.push('env', name);
                pushFlag(args, '--project', projectDir ? targetDir : undefined);
                pushFlag(args, '--namespace', namespace);
                pushFlag(args, '--storage-class', storageClass);
            } else if (initKind === 'release') {
                args.push('release', version || name);
                pushFlag(args, '--project', projectDir ? targetDir : undefined);
                pushFlag(args, '--storage-class', storageClass);
            } else {
                args.push('factory');
                if (factoryDir) {
                    args.push('--factory', factoryDir);
                }
                workDir = targetDir;
            }

            ctx.logger.info(
                `Initializing ${initKind} "${name}" in ${workDir}`,
            );

            await executeKoncept(args, {
                cwd: workDir,
                logger: ctx.logger,
            });

            ctx.output('workDir', workDir);

            ctx.logger.info(`Initialized ${initKind} "${name}"`);
        },
    });
}
