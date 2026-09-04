import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/product_models.dart';
final productsProvider=FutureProvider.family<List<Product>,ProductCategory>((ref,category)async{final b=(await ref.read(dioProvider).get('/marketplace/products',queryParameters:{'category':category==ProductCategory.equipment?'EQUIPMENT':'FEED_NUTRITION'})).data as Map<String,dynamic>;return (b['data'] as List).map((x)=>Product.fromJson(x)).toList();});
final productDetailProvider=FutureProvider.family<Product,String>((ref,id)async{final b=(await ref.read(dioProvider).get('/marketplace/products/$id')).data as Map<String,dynamic>;return Product.fromJson(b['data']);});
