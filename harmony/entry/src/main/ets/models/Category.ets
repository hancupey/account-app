export type CategoryType = 'income' | 'expense';

export class Category {
  id: number = 0;
  name: string = '';
  type: CategoryType = 'expense';
  icon: string = '';
  sortOrder: number = 0;
  isSystem: boolean = false;
}
