SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name IN ('expire_offers', 'send_renewal_reminders', 'admin_set_offer_priority_internal');
