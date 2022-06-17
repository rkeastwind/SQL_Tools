select * into #end_bnd_bal from inv_bnd_bal

          --分攤結帳單位金額
          --欄位：攤銷後成本(含Acc)、帳載攤銷折溢價(含Acc)
          SELECT
                 --排序條件(依照I_GroupKey分類，給最大)
				 ROW_NUMBER() OVER (PARTITION BY A.code + '|' + CAST(A.pno AS NVARCHAR) + '|' + CAST(A.cap_tp AS NVARCHAR) + '|' + A.trade_no
                                    ORDER BY A.org_par_value DESC) AS I_Rank,
                 --基本資料
                 A.code, A.pno, A.fno, A.cap_tp, A.trade_no,
                 A.code + '|' + CAST(A.pno AS NVARCHAR) + '|' + CAST(A.cap_tp AS NVARCHAR) + '|' + A.trade_no + '|' + A.fno AS I_Key,
                 A.code + '|' + CAST(A.pno AS NVARCHAR) + '|' + CAST(A.cap_tp AS NVARCHAR) + '|' + A.trade_no AS I_GroupKey,
                 --原始資料
                 B.cost AS I_cost,
                 B.acc_cost AS I_acc_cost,
                 B.eom_amortize AS I_eom_amortize,
                 B.acc_eom_amortize AS I_acc_eom_amortize,
                 --按比率分攤做無條件捨去
                 ROUND((CASE WHEN B.org_par_value <> 0 THEN B.cost             * A.org_par_value / B.org_par_value ELSE B.cost END)             ,dbo.fn_GetCcyDigit(C.ccy),1) AS O_cost,
                 ROUND((CASE WHEN B.org_par_value <> 0 THEN B.acc_cost         * A.org_par_value / B.org_par_value ELSE B.acc_cost END)         ,dbo.fn_GetCcyDigit(D.book_ccy),1) AS O_acc_cost,
                 ROUND((CASE WHEN B.org_par_value <> 0 THEN B.eom_amortize     * A.org_par_value / B.org_par_value ELSE B.eom_amortize END)     ,dbo.fn_GetCcyDigit(C.ccy),1) AS O_eom_amortize,
                 ROUND((CASE WHEN B.org_par_value <> 0 THEN B.acc_eom_amortize * A.org_par_value / B.org_par_value ELSE B.acc_eom_amortize END) ,dbo.fn_GetCcyDigit(D.book_ccy),1) AS O_acc_eom_amortize
            INTO #For_AllowCation
            FROM #end_bnd_bal A
      INNER JOIN #end_bnd_bal B
              ON A.code = B.code
             AND A.pno = B.pno
             AND A.cap_tp = B.cap_tp
             AND A.trade_no = B.trade_no
             AND B.fno = ''  --結帳單位
       LEFT JOIN cmn_bond C ON A.code = C.code
       LEFT JOIN ims_invt_unit D ON A.pno = D.pno
           WHERE A.fno != ''  --投組

          --調尾差(有兩筆以上的最大那一筆需要調整)
          UPDATE A SET
                 O_cost             = O_cost             +(A.I_cost             - B.Sum_cost),
                 O_acc_cost         = O_acc_cost         +(A.I_acc_cost         - B.Sum_acc_cost),
                 O_eom_amortize     = O_eom_amortize     +(A.I_eom_amortize     - B.Sum_eom_amortize),
                 O_acc_eom_amortize = O_acc_eom_amortize +(A.I_acc_eom_amortize - B.Sum_acc_eom_amortize)
            FROM #For_AllowCation A
       LEFT JOIN (
                  SELECT I_GroupKey, COUNT(*) AS I_Count,
                      SUM(O_cost)             AS Sum_cost,
                      SUM(O_acc_cost)         AS Sum_acc_cost,
                      SUM(O_eom_amortize)     AS Sum_eom_amortize,
                      SUM(O_acc_eom_amortize) AS Sum_acc_eom_amortize
                    FROM #For_AllowCation GROUP BY I_GroupKey) B ON A.I_GroupKey = B.I_GroupKey
           WHERE B.I_Count > 1 AND A.I_Rank = 1
