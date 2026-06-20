import os

file_path = 'lib/providers/offer_provider.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''      final response = await SupabaseService().client.rpc(
        'get_user_offers_internal',
        params: {'p_user_uid': userId},
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'list',
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Unknown error');
      final list = data['offers'] as List;'''
)

content = content.replace(
'''      final response = await SupabaseService().client.rpc(
        'get_offer_by_id_internal',
        params: {
          'p_offer_id': offerId,
          'p_user_uid': userId,
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'get_by_id',
          'offer_id': offerId,
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return null;
      final offerData = data['offer'];
      if (offerData == null) return null;'''
)

content = content.replace(
'''      await SupabaseService().client.rpc(
        'create_offer_internal',
        params: {
          'p_user_uid': userId,
          'p_offer': offer.toMap(),
        },
      );''',
'''      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'create',
          'user_uid': userId,
          'offer': offer.toMap(),
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Unknown error');'''
)

content = content.replace(
'''      await SupabaseService().client.rpc(
        'increment_offer_views_internal',
        params: {'p_offer_id': offerId},
      );''',
'''      await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'increment_views',
          'offer_id': offerId,
        },
      );'''
)

# Fix map parsing 
content = content.replace(
'''      return (response as List)
          .map((item) => OfferModel.fromSupabase(
                Map<String, dynamic>.from(item),
                item['id'] as String,
              ))
          .toList();''',
'''      return list
          .map((item) => OfferModel.fromSupabase(
                Map<String, dynamic>.from(item),
                item['id'] as String,
              ))
          .toList();'''
)

content = content.replace(
'''      final data = response as Map<String, dynamic>?;

      if (data == null) return null;

      return OfferModel.fromSupabase(
        data,
        data['id'] as String,
      );''',
'''      return OfferModel.fromSupabase(
        Map<String, dynamic>.from(offerData),
        offerData['id'] as String,
      );'''
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
