#!/usr/bin/python3

import sys, os
import numpy as np
import pandas as pd


# build the prediction dataframe (self.df) and ranking dataframe (self.rank_df)
# if no rank_ref_file, build a new one
class Predictions():
    def __init__(self, bfile_prefix, pred_prefix, method, rank_ref_file=None):
        self.bfile_prefix = bfile_prefix
        self.pred_prefix = pred_prefix
        self.method = method
        self.rank_ref_file = rank_ref_file
        self.df = pd.read_csv('{}.fam'.format(bfile_prefix), sep='\s+', names=['FID', 'IID', 'father', 'mother', 'sex', 'phenotype'])
        self.df = self.df[['FID', 'IID', 'phenotype']]
        if self.method == 'clf':
            self.df['phenotype'] = self.df['phenotype'].apply(lambda x: x - 1 if (x == 1) | (x == 2) else x) # control = 0, case = 1
        self.df['phenotype'].replace(-9, np.nan, inplace=True)


    def __call__(self):
        print('\n\n###### Building Prediction Dataframe ######\n\n')
        ### prediction dataframe
        print('Loading prediction dataframe ...')
        for tool in ['CandT', 'PRSice2', 'Lassosum', 'LDpred2', 'PRScs']:
            file = '{}.{}.profile'.format(self.pred_prefix, tool)
            self.df = self._append_score(self.df, file, tool)
        # GenEpi
        file = '{}.GenEpi.csv'.format(self.pred_prefix)
        self.df = self._append_score(self.df, file, 'GenEpi', sep=',', prev_col='score')
        print('Available algorithms:', ', '.join(self.df.columns[3:]))


        ### checking NA
        # fill NA with minimum
        # if NA > 10%, drop the algorithm
        print('Checking NA ...')
        num = self.df.shape[0]
        for tool in self.df.columns[3:]:
            na_count = self.df[tool].isna().sum()
            print('NA count of {} = {} / {}, {:.2f}%'.format(tool, na_count, num, na_count/num*100))
            if na_count/num > 0.1:
                self.df = self.df.drop(columns=[tool])
                print('Drop {} because more than 10\% are NA'.format(tool))
            else:
                minimum = self.df[tool].min()
                self.df[tool] = self.df[tool].fillna(minimum)
                print('Fill {} with minimum ({})'.format(tool, minimum))
        

        ### ranking dataframe
        if self.rank_ref_file:
            print('Loading provided ranking reference ...')
            self.rank_ref_df = pd.read_csv(self.rank_ref_file, index_col=0)
        else:
            print('Building ranking reference ...')
            self.rank_ref_df = self._build_rank_ref(self.df)
        print('Mapping ranking score ...')
        self.rank_df = self._map_rank(self.df, self.rank_ref_df)

        print('\n\n###### Complete ######\n\n')


    def _append_score(self, df, file, post_col, sep='\s+', prev_col='SCORESUM'):
        if not os.path.isfile(file):
            return df
        pred_df = pd.read_csv(file, sep=sep)
        pred_df = pred_df[['FID', 'IID', prev_col]]
        pred_df = pred_df.rename(columns={prev_col: post_col})
        df = df.merge(pred_df, on=['FID', 'IID'], how='left')
        return df


    def _build_rank_ref(self, df):
        rank_list = list(range(100)) + [99.5, 99.7, 99.9, 100]
        rank_df = pd.DataFrame(index=rank_list)
        for tool in df.columns[3:]:
            rank_score = np.percentile(df[tool], rank_list)
            rank_df[tool] = rank_score
        return rank_df


    def _map_rank(self, df, rank_ref_df):
        rank_df = df.loc[:, df.columns[:3]]
        for tool in df.columns[3:].tolist():
            if tool not in rank_ref_df.columns.tolist():
                continue
            interp_rank = np.interp(df[tool], rank_ref_df[tool], rank_ref_df.index.tolist())
            rank_df[tool] = interp_rank
        return rank_df