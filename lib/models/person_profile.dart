import 'package:flutter/material.dart';

/// 人物画像 —— 八维度（对应 E:\animatrix\外脑人物画像框架.md）。
/// 这是「这个人是谁」的长时静态画像，与「事件记忆」分离存储。

/// 基本信息字段（前期配置，可标注「必填」）
class BasicField {
  final String label;
  final String value;
  final bool required; // 前期配置必填（如名称）
  const BasicField({
    required this.label,
    required this.value,
    this.required = false,
  });
}

class PersonProfile {
  final String name;
  final String greeting;
  final List<BasicField> basics; // 基本信息（姓名/外脑名等，必填标注）
  final List<ProfileDimension> dimensions;

  const PersonProfile({
    required this.name,
    required this.greeting,
    required this.basics,
    required this.dimensions,
  });
}

class ProfileDimension {
  final String title;
  final IconData icon;
  final int color;
  final List<String> items;

  const ProfileDimension({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

/// 曲炳阳的画像 —— 当前已采集的真实信息（空维度 = 待主动采集补全）。
const PersonProfile qbyProfile = PersonProfile(
  name: '曲炳阳',
  greeting: '1997 年出生 · 黑龙江佳木斯人',
  basics: [
    BasicField(label: '姓名', value: '曲炳阳', required: true),
    BasicField(label: '外脑名', value: 'animatrix', required: true),
    BasicField(label: '出生', value: '1997 年'),
    BasicField(label: '籍贯', value: '黑龙江佳木斯'),
    BasicField(label: '性别', value: '男'),
    BasicField(label: '角色', value: '外脑项目创始人'),
  ],
  dimensions: [
    ProfileDimension(
      title: '身份',
      icon: Icons.badge_outlined,
      color: 0xFF00D4FF,
      items: [
        '1997 年出生，男性',
        '黑龙江佳木斯人（东北人）',
        '正在创业「个人随身 AI 外脑」',
      ],
    ),
    ProfileDimension(
      title: '身体',
      icon: Icons.accessibility_new,
      color: 0xFF00E5A0,
      items: [
        '身高 175cm',
        '穿衣风格独特，爱逛古着店挑稀奇配饰',
      ],
    ),
    ProfileDimension(
      title: '性格',
      icon: Icons.psychology_outlined,
      color: 0xFF7B61FF,
      items: [
        // 待主动采集补全
      ],
    ),
    ProfileDimension(
      title: '认知',
      icon: Icons.lightbulb_outline,
      color: 0xFFFFB020,
      items: [
        // 待主动采集补全
      ],
    ),
    ProfileDimension(
      title: '偏好',
      icon: Icons.favorite_outline,
      color: 0xFFFF5C7A,
      items: [
        '爱吃韩料，尤其铁板鸡',
        '爱烧鸟，常去杭州庆春路「和炙烧鸟」',
        '近三年爱喝金宾（Jim Beam），做嗨棒',
        '爱打羽毛球',
        '最爱动漫《NANA》，已看六七遍',
      ],
    ),
    ProfileDimension(
      title: '价值观',
      icon: Icons.flag_outlined,
      color: 0xFF00D4FF,
      items: [
        '产品判断：记忆体系才是核心壁垒，交互形态无护城河',
        '隐私底线：只要不被公网检索即可，真实身份与水务项目网络隔离',
      ],
    ),
    ProfileDimension(
      title: '关系',
      icon: Icons.people_outline,
      color: 0xFF00E5A0,
      items: [
        '女朋友：王一如（常接送、共餐，关系亲近）',
        '好友：肖悦、乐乐（首次带去和炙烧鸟）',
      ],
    ),
    ProfileDimension(
      title: '经历',
      icon: Icons.timeline,
      color: 0xFF7B61FF,
      items: [
        '有读博规划，未来博导在杭州电子科技大学（杭电）',
        '高三起看《NANA》，影响深远',
        '创业中：外脑项目规划 V1→V3，拟天使轮融资 500 万',
      ],
    ),
  ],
);
