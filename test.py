import unittest


import os
import sys
import numpy as np
from cylp.cy import CyClpSimplex
from cylp.py.modeling.CyLPModel import CyLPArray
#import setuptools
#import toolz
#import six
#import fastcache
#import multiprocess
#import ecos
#import scs
#import scipy
import cvxpy
import CVXcanon
#import nose
import logging
import json
from calendar import timegm
import datetime as dt
import unittest
import pprint as pp
import copy
import time
from inspect import getframeinfo, stack
import random

class TestLambda(unittest.TestCase):

    def test_dummy(self):
        self.assertEqual(True, True)

    def test_cylp(self):
        s = CyClpSimplex()

        numStates = 5

        # Add variables
        x = s.addVariable('x', numStates, isInt=True)
        sw_on = s.addVariable('sw_on', numStates, isInt=True)
        sw_off = s.addVariable('sw_off', numStates, isInt=True)
        sw_stay_on = s.addVariable('sw_stay_on', numStates, isInt=True)
        sw_stay_off = s.addVariable('sw_stay_off', numStates, isInt=True)

        # Add constraints
        # make bools
        for b in [x,sw_on,sw_off,sw_stay_off,sw_stay_on]:
            s += b <= 1
            s += b >= 0

        # must be one of the transitions
        s += sw_on + sw_off + sw_stay_on + sw_stay_off == 1

        # if sw_on
        for i in range(numStates):
            # must be on now
            s += x[i] - sw_on[i] >=0

            # was off last time
            if i>0:
                s += (1-x[i-1] ) - sw_on[i] >= 0

        # if sw_off
        for i in range(numStates):
            # must be off now
            s += (1-x[i]) - sw_off[i] >= 0

            # was on last time
            if i>0:
                s += x[i-1] - sw_on[i] >= 0

        # if sw_stay_on
        for i in range(numStates):
            s += x[i] - sw_stay_on[i] >= 0
            if i > 0:
                s += x[i-1] - sw_stay_on[i] >= 0

        # if sw_stay_off
        for i in range(numStates):
            s += (1-x[i]) - sw_stay_off[i] >= 0
            if i > 0:
                s += (1-x[i-1]) - sw_stay_off[i] >= 0

        s += x[1] == 1
        s += x[2] == 0

        # Set the objective function
        s.objective = x[0] - x[1] + x[2]

        # Solve using primal Simplex
        s.primal()
        print(' | '.join(['i','x','on','off','stay on','stay off']))
        for i in range(numStates):
            row=' | '.join([
                '%d' % i,
                '%1d' % s.primalVariableSolution['x'][i],
                '%2d' % s.primalVariableSolution['sw_on'][i],
                '%3d' % s.primalVariableSolution['sw_off'][i],
                '%7d' % s.primalVariableSolution['sw_stay_on'][i],
                '%8d' % s.primalVariableSolution['sw_stay_off'][i]
            ])

            print(row)
        print('cylp ran (not necessarily go a solution)')



    def test_cvxpy(self):
        A = cvxpy.Variable(1,name='A')
        B = cvxpy.Variable(1,name='B')
        constr = []
        constr.append(-1 <= B)
        constr.append(B <= 5)
        constr.append(0 <= A)
        constr.append(A <= 1)
        obj = cvxpy.Maximize(A - B)
        problem = cvxpy.Problem(obj, constr)
        ret = problem.solve()
        if problem.status not in [cvxpy.OPTIMAL, cvxpy.OPTIMAL_INACCURATE]:
            print('problem status: ' + problem.status)
        self.assertTrue(problem.status in [cvxpy.OPTIMAL, cvxpy.OPTIMAL_INACCURATE])


    def test_CBC(self):
        A = cvxpy.Bool(1,name='A')
        B = cvxpy.Variable(1,name='B')
        constr = []
        constr.append(-1 <= B)
        constr.append(B <= 5)
        obj = cvxpy.Maximize(A - B)
        problem = cvxpy.Problem(obj, constr)
        ret = problem.solve(solver=cvxpy.CBC)
        self.assertTrue(problem.status in [cvxpy.OPTIMAL, cvxpy.OPTIMAL_INACCURATE])



    def test_CBC_hard(self):

        num_states = 5
        x = cvxpy.Bool(num_states,name='x')
        sw_on = cvxpy.Bool(num_states,name='sw_on')
        sw_off = cvxpy.Bool(num_states,name='sw_off')
        sw_stay_on = cvxpy.Bool(num_states,name='sw_stay_on')
        sw_stay_off = cvxpy.Bool(num_states,name='sw_stay_off')
        fl = cvxpy.Variable(num_states,name='float')

        constr = []

        # can only be one transition type
        constr.append(sw_on*1.0 + sw_off*1.0 + sw_stay_on*1.0 + sw_stay_off*1.0 == 1)

        for i in range(num_states):
            # if switching on, must be now on
            constr.append(x[i] >= sw_on[i])

            # if switchin on, must have been off previously
            if i>0:
                constr.append((1-x[i-1]) >= sw_on[i])

            # if switching off, must be now off
            constr.append((1-x[i]) >= sw_off[i])

            # if switchin off, must have been on previously
            if i>0:
                constr.append(x[i-1] >= sw_off[i])

            # if staying on, must be now on
            constr.append(x[i] >= sw_stay_on[i])

            # if staying on, must have been on previously
            if i>0:
                constr.append(x[i-1] >= sw_stay_on[i])

            # if staying, must be now off
            constr.append((1-x[i]) >= sw_stay_off[i])

            # if staying off, must have been off previously
            if i>0:
                constr.append((1-x[i-1]) >= sw_stay_off[i])


        # random stuff
        constr.append(x[1] == 1)
        constr.append(x[3] == 0)
        for i in range(num_states):
            constr.append(fl[i] <= i*sw_on[i])
            constr.append(fl[i] >= -i)


        obj = cvxpy.Maximize(sum(sw_off) + sum(sw_on))
        for i in range(num_states):
            if i%2 == 0:
                obj += cvxpy.Maximize(fl[i])
            else:
                obj += cvxpy.Maximize(-1*fl[i])
        problem = cvxpy.Problem(obj, constr)
        ret = problem.solve(solver=cvxpy.CBC)
        self.assertTrue(problem.status in [cvxpy.OPTIMAL, cvxpy.OPTIMAL_INACCURATE])

        print(' | '.join(['i','x','sw_on','sw_off','stay_on','stay_off','float']))
        for i in range(num_states):
            row = ' | '.join([
                '%1d' % i,
                '%1d' % int(round(x[i].value)),
                '%5d' % int(round(sw_on[i].value)),
                '%6d' % int(round(sw_off[i].value)),
                '%7d' % int(round(sw_stay_on[i].value)),
                '%8d' % int(round(sw_stay_off[i].value)),
                '%f' % fl[i].value
            ])
            print(row)

    def test_cylp_packaging(self):

        # https://github.com/coin-or/CyLP#modeling-example
        s = CyClpSimplex()

        # Add variables
        x = s.addVariable('x', 3)
        y = s.addVariable('y', 2)

        # Create coefficients and bounds
        A = np.matrix([[1., 2., 0],[1., 0, 1.]])
        B = np.matrix([[1., 0, 0], [0, 0, 1.]])
        D = np.matrix([[1., 2.],[0, 1]])
        a = CyLPArray([5, 2.5])
        b = CyLPArray([4.2, 3])
        x_u= CyLPArray([2., 3.5])

        # Add constraints
        s += A * x <= a
        s += 2 <= B * x + D * y <= b
        s += y >= 0
        s += 1.1 <= x[1:3] <= x_u

        # Set the objective function
        c = CyLPArray([1., -2., 3.])
        s.objective = c * x + 2 * y.sum()

        # Solve using primal Simplex
        s.primal()
        print s.primalVariableSolution['x']

    # test the COIN solver is packaged correctly
    def test_CBC_packaging_simple(self):
        num_states = 5
        A = cvxpy.Bool(num_states,name='A')
        B = cvxpy.Variable(num_states,name='B')
        constr = []
        for i in range(1,num_states):
            constr.append(1.0*A[i-1] + 1.0*A[i] <= 1.0)

        for i in range(num_states):
            constr.append(B[i] <= i)

        objs = []
        for i in range(num_states):
            objs.append(cvxpy.Maximize(A[i] - B[i]))
        problem = cvxpy.Problem(sum(objs), constr)
        ret = problem.solve(solver=cvxpy.CBC)
        self.assertTrue(problem.status in [cvxpy.OPTIMAL, cvxpy.OPTIMAL_INACCURATE])
