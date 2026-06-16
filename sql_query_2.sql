SELECT 
  EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'tp'
  ) AS has_tp,
  EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'act'
  ) AS has_act;
