import { Item } from './Item';
import { InventoryDomain } from './InventoryDomain';

export interface UserProfile {
  displayName: string;
  avatarKey: string;
  bio: string;
  allergies: string[];
  dislikes: string[];
  preferences: string[];
}
export interface AvatarChoice { key: string; label: string; symbol: string; color: string; }
export class ProfileDomain {
  static readonly avatars: AvatarChoice[] = [
    { key: 'leaf', label: '新叶', symbol: '🌿', color: '#E4F0DF' },
    { key: 'cat', label: '小猫', symbol: '🐱', color: '#F9E5D2' },
    { key: 'coffee', label: '咖啡', symbol: '☕', color: '#EBDDD3' },
    { key: 'sun', label: '暖阳', symbol: '☀', color: '#FCEDBB' },
    { key: 'moon', label: '月亮', symbol: '🌙', color: '#E9E3F5' },
    { key: 'flower', label: '小花', symbol: '🌸', color: '#F8E1E8' },
    { key: 'ocean', label: '海浪', symbol: '🌊', color: '#DDECF8' },
    { key: 'star', label: '星星', symbol: '⭐', color: '#F4EDCB' }
  ];
  static empty(name: string = ''): UserProfile { return { displayName: name, avatarKey: 'leaf', bio: '', allergies: [], dislikes: [], preferences: [] }; }
  static avatar(key: string): AvatarChoice { return ProfileDomain.avatars.find((a: AvatarChoice) => a.key === key) ?? ProfileDomain.avatars[0]; }
  static tags(text: string): string[] {
    const result: string[] = [];
    for (const value of text.split(/[,，、;；\n]/)) { const clean = value.trim(); if (clean && !result.includes(clean)) result.push(clean); }
    return result;
  }
  static validate(profile: UserProfile): string {
    if (!profile.displayName.trim() || profile.displayName.trim().length > 40) return '昵称需为 1–40 个字符';
    if (!ProfileDomain.avatars.some((a: AvatarChoice) => a.key === profile.avatarKey)) return '请选择头像';
    if (profile.bio.length > 120) return '个性签名最多 120 个字符';
    for (const group of [profile.allergies, profile.dislikes, profile.preferences]) {
      if (group.length > 20 || group.some((tag: string) => !tag.trim() || tag.length > 24)) return '每类最多 20 项，每项最多 24 个字符';
    }
    return '';
  }
  static advice(item: Item, today: string, profile: UserProfile): string {
    const base = InventoryDomain.advice(item, today);
    if (item.categoryId !== 'food') return base;
    const text = `${item.name} ${item.notes ?? ''}`.toLowerCase();
    const matches = profile.allergies.concat(profile.dislikes).filter((tag: string) => text.includes(tag.toLowerCase()));
    if (matches.length) return `名称或备注命中你的忌口：${matches.join('、')}。请先核对包装配料，不据此推荐食用。${base}`;
    return profile.preferences.length ? `${base} 你的偏好：${profile.preferences.join('、')}，选用前请核对包装信息。` : base;
  }
}
