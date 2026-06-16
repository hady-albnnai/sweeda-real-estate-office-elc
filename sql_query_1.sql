SELECT 
  EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'offers' AND column_name = 'i_pin'
  ) AS has_ipin,
  EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'offers' AND column_name = 'pin_end'
  ) AS has_pinend,
  EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'offers' AND column_name = 'i_bst'
  ) AS has_ibst,
  EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'offers' AND column_name = 'i_fms'
  ) AS has_ifms,
  EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'offers' AND column_name = 'ts_end'
  ) AS has_tsend,
  EXISTS (
    SELECT FROM information_schema.columns 
    WHERE table_name = 'offers' AND column_name = 'ts_ren'
  ) AS has_tsren;
