import { konceptRenderAction } from './render';
import { konceptValidateAction } from './validate';
import { konceptInitAction } from './init';
import { konceptPublishAction } from './publish';

/**
 * Returns all koncept scaffolder actions for registration in a Backstage backend.
 *
 * Usage in packages/backend/src/index.ts:
 *   import { createKonceptActions } from '@idp-concept/backstage-plugin-koncept-actions';
 *   backend.add(createKonceptActions());
 */
export function createKonceptActions() {
    return [
        konceptRenderAction(),
        konceptValidateAction(),
        konceptInitAction(),
        konceptPublishAction(),
    ];
}
