import { ImportDraft } from '../../models/ImportDraft';
import { TransactionRepository } from '../../database/TransactionRepository';

export class ImportDedupeUtil {
  static applyToDraft(draft: ImportDraft): void {
    draft.dedupeKey = TransactionRepository.buildDedupeKey(
      draft.amount,
      draft.type,
      draft.occurredAt,
      draft.payee
    );
  }
}
