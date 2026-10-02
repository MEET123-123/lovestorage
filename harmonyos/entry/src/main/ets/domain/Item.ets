export interface Item {
  id: string;
  name: string;
  categoryId: string;
  expiryDate?: string;
  lifecycleStatus: string;
  createdAt: number;
  updatedAt: number;
  deletedAt?: number;
}
